import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../../core/api/dio_factory.dart';
import '../../../../../core/cache/cache_helper.dart';
import '../../../../../core/errors/exception.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../data/model/phone_login_response_model.dart';
import '../../../data/repo/auth_repo.dart';

part 'phone_auth_state.dart';

/// Captain phone OTP auth — Firebase phone authentication. The verified Firebase
/// ID token is exchanged with the backend (`phone-login-driver` / `phone-register-driver`).
class PhoneAuthCubit extends Cubit<PhoneAuthState> {
  PhoneAuthCubit(this._authRepo) : super(const PhoneAuthState());

  final AuthRepo _authRepo;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;
  Timer? _cooldownTimer;

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }

  Future<void> sendCode(String rawPhone) async {
    final phone = _toE164(rawPhone);
    emit(state.copyWith(
      status: PhoneAuthStatus.sendingCode,
      phone: phone,
      clearError: true,
      cooldownSeconds: 0,
    ));
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _signInAndLogin(credential);
        },
        verificationFailed: (e) {
          if (isClosed) return;
          emit(state.copyWith(
            status: PhoneAuthStatus.codeSendFailure,
            errorMessage: _firebaseMsg(e),
          ));
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (isClosed) return;
          emit(state.copyWith(status: PhoneAuthStatus.codeSent));
          _startCooldown();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.codeSendFailure,
        errorMessage: _firebaseMsg(e),
      ));
    }
  }

  Future<void> verifyCode(String code) async {
    final vid = _verificationId;
    if (vid == null) {
      emit(state.copyWith(
        status: PhoneAuthStatus.verifyFailure,
        errorMessage: 'لم يتم إرسال رمز التحقق بعد.',
      ));
      return;
    }
    emit(state.copyWith(status: PhoneAuthStatus.verifying, clearError: true));
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: code,
      );
      await _signInAndLogin(credential);
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.verifyFailure,
        errorMessage: _firebaseMsg(e),
      ));
    }
  }

  /// Signs in with the Firebase credential, then exchanges the ID token with the
  /// backend driver login endpoint. A new phone, or an existing non-driver, is
  /// routed to captain sign-up (newUser).
  Future<void> _signInAndLogin(PhoneAuthCredential credential) async {
    final userCred = await _auth.signInWithCredential(credential);
    final idToken = await userCred.user?.getIdToken();
    if (idToken == null) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.verifyFailure,
        errorMessage: 'فشل الحصول على رمز التحقق.',
      ));
      return;
    }
    final result = await _authRepo.phoneLogin(
      idToken: idToken,
      fcmToken: (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '',
      deviceType: AppConstants.deviceType,
    );
    if (isClosed) return;
    if (result.isNewUser) {
      emit(state.copyWith(
        status: PhoneAuthStatus.newUser,
        phone: result.phone ?? state.phone,
      ));
    } else {
      await _cacheSession(result);
      emit(state.copyWith(status: PhoneAuthStatus.loginSuccess));
    }
  }

  Future<void> registerDriver({
    required String fullName,
    String? email,
    String? gender,
    String? nationalId,
    String? driverLicense,
    required int scooterType,
    String? scooterLicense,
  }) async {
    emit(state.copyWith(status: PhoneAuthStatus.verifying, clearError: true));
    try {
      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken == null) {
        emit(state.copyWith(
          status: PhoneAuthStatus.verifyFailure,
          errorMessage: 'انتهت الجلسة، يرجى إعادة المحاولة.',
        ));
        return;
      }
      final result = await _authRepo.phoneRegisterDriver(
        idToken: idToken,
        fullName: fullName,
        email: email,
        gender: gender,
        nationalId: nationalId,
        driverLicense: driverLicense,
        scooterType: scooterType,
        scooterLicense: scooterLicense,
        fcmToken: (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '',
        deviceType: AppConstants.deviceType,
      );
      if (isClosed) return;
      await _cacheSession(result);
      emit(state.copyWith(status: PhoneAuthStatus.loginSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.verifyFailure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  /// Google Sign-In for captain. Stores Google ID token in state for re-use
  /// when the user completes the driver signup form.
  Future<void> googleSignIn() async {
    emit(state.copyWith(status: PhoneAuthStatus.sendingCode, clearError: true));
    try {
      const webClientId =
          '792221536894-jqrpntom44mkat6kfn1lj916g5lp79a0.apps.googleusercontent.com';
      final googleSignIn = GoogleSignIn(serverClientId: webClientId);
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) {
        if (isClosed) return;
        emit(state.copyWith(status: PhoneAuthStatus.initial));
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (isClosed) return;
        emit(state.copyWith(
          status: PhoneAuthStatus.codeSendFailure,
          errorMessage: 'فشل الحصول على رمز Google.',
        ));
        return;
      }
      // Store token as lastCode for reuse in registerDriver.
      // Try login first (in case user is already a driver).
      final fcmToken =
          (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '';
      final result = await _authRepo.googleTokenDriver(
        idToken: idToken,
        fcmToken: fcmToken,
        deviceType: AppConstants.deviceType,
      );
      if (isClosed) return;
      if (result.isNewUser) {
        emit(state.copyWith(
          status: PhoneAuthStatus.newUser,
          // Reuse lastCode field to carry the Google ID token.
          lastCode: idToken,
        ));
      } else {
        await _cacheSession(result);
        emit(state.copyWith(status: PhoneAuthStatus.loginSuccess));
      }
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.codeSendFailure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  /// Called after Google sign-in returns isNewUser=true and user fills form.
  Future<void> registerDriverWithGoogle({
    required String fullName,
    String? email,
    String? gender,
    String? nationalId,
    String? driverLicense,
    required int scooterType,
    String? scooterLicense,
  }) async {
    emit(state.copyWith(status: PhoneAuthStatus.verifying, clearError: true));
    try {
      final fcmToken =
          (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '';
      final result = await _authRepo.googleTokenDriver(
        idToken: state.lastCode, // lastCode holds the Google ID token
        fullName: fullName,
        gender: gender,
        nationalId: nationalId,
        driverLicense: driverLicense,
        scooterType: scooterType,
        scooterLicense: scooterLicense,
        fcmToken: fcmToken,
        deviceType: AppConstants.deviceType,
      );
      if (isClosed) return;
      await _cacheSession(result);
      emit(state.copyWith(status: PhoneAuthStatus.loginSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.verifyFailure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  void _startCooldown([int seconds = 30]) {
    _cooldownTimer?.cancel();
    emit(state.copyWith(cooldownSeconds: seconds));
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (isClosed) { t.cancel(); return; }
      final remaining = state.cooldownSeconds - 1;
      if (remaining <= 0) {
        t.cancel();
        emit(state.copyWith(cooldownSeconds: 0));
      } else {
        emit(state.copyWith(cooldownSeconds: remaining));
      }
    });
  }

  Future<void> _cacheSession(PhoneLoginResponseModel r) async {
    final token = r.token ?? '';
    final refresh = r.refreshToken ?? '';
    final userId = r.userId ?? '';
    final role = r.role ?? '';
    final name = r.name ?? '';
    final pic = r.profilePicture ?? '';
    await CacheHelper.setSecuredString(AppConstants.token, token);
    await CacheHelper.setSecuredString(AppConstants.refreshToken, refresh);
    await CacheHelper.setSecuredString(AppConstants.userId, userId);
    await CacheHelper.setData(key: AppConstants.role, value: role);
    await CacheHelper.setData(key: AppConstants.userName, value: name);
    await CacheHelper.setData(key: AppConstants.profileImage, value: pic);
    AppConstants.kToken = token;
    AppConstants.kUserId = userId;
    AppConstants.kRole = role;
    AppConstants.kUserName = name;
    AppConstants.kProfileImage = pic;
    await DioFactory.setTokenIntoHeaderAfterLogin(token);
  }

  String _toE164(String phone) {
    var p = phone.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (p.startsWith('+')) return p;
    if (p.startsWith('00')) return '+${p.substring(2)}';
    if (p.startsWith('0')) p = p.substring(1);
    return '+20$p';
  }

  String _firebaseMsg(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'رقم الهاتف غير صحيح.';
        case 'invalid-verification-code':
          return 'رمز التحقق غير صحيح.';
        case 'too-many-requests':
          return 'محاولات كثيرة، يرجى المحاولة لاحقًا.';
        case 'session-expired':
          return 'انتهت صلاحية الرمز، اطلب رمزًا جديدًا.';
        default:
          return e.message ?? 'حدث خطأ، يرجى المحاولة لاحقًا.';
      }
    }
    return ServerFailure.fromError(e).errMessage;
  }
}
