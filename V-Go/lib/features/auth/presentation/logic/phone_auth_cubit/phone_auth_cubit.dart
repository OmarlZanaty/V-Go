import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/api/dio_factory.dart';
import '../../../../../core/cache/cache_helper.dart';
import '../../../../../core/errors/exception.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../data/model/phone_login_response_model.dart';
import '../../../data/repo/auth_repo.dart';

part 'phone_auth_state.dart';

/// Rider auth: phone number + password. After the phone is entered we check
/// whether it's already registered (-> enter password) or new (-> set password
/// + profile). Firebase OTP is kept ONLY for forgot-password.
class PhoneAuthCubit extends Cubit<PhoneAuthState> {
  PhoneAuthCubit(this._authRepo) : super(const PhoneAuthState());

  final AuthRepo _authRepo;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;
  String? _resetIdToken; // Firebase id token captured during forgot-password
  Timer? _cooldownTimer;

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }

  /// Back to the phone-entry step (e.g. user taps back from the password step).
  void reset() => emit(PhoneAuthState(phone: state.phone));

  // ---------------- phone + password sign-in ----------------

  /// Step 1: after the phone field, check whether the number is registered.
  Future<void> checkPhone(String rawPhone) async {
    final phone = _toE164(rawPhone);
    emit(state.copyWith(
        status: PhoneAuthStatus.checkingPhone, phone: phone, clearError: true));
    try {
      final exists = await _authRepo.checkPhoneExists(phone);
      if (isClosed) return;
      emit(state.copyWith(
        status: exists ? PhoneAuthStatus.existingUser : PhoneAuthStatus.newUser,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  /// Returning user: phone (from state) + password.
  Future<void> login(String password) async {
    emit(state.copyWith(
        status: PhoneAuthStatus.authenticating, clearError: true));
    try {
      final fcmToken =
          (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '';
      final result = await _authRepo.phoneLogin(
        phone: state.phone,
        password: password,
        fcmToken: fcmToken,
        deviceType: 'Android',
      );
      if (isClosed) return;
      await _cacheSession(result);
      emit(state.copyWith(status: PhoneAuthStatus.loginSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  /// New user: phone (from state) + the password they just set + profile data.
  Future<void> register({
    required String password,
    required String fullName,
    String? email,
    String? gender,
  }) async {
    emit(state.copyWith(
        status: PhoneAuthStatus.authenticating, clearError: true));
    try {
      final fcmToken =
          (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '';
      final result = await _authRepo.phoneRegister(
        phone: state.phone,
        password: password,
        fullName: fullName,
        email: email,
        gender: gender,
        fcmToken: fcmToken,
        deviceType: 'Android',
      );
      if (isClosed) return;
      await _cacheSession(result);
      emit(state.copyWith(status: PhoneAuthStatus.loginSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  // ---------------- forgot password (Firebase OTP) ----------------

  Future<void> sendResetCode(String rawPhone) async {
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
          await _captureResetToken(credential);
        },
        verificationFailed: (e) {
          if (isClosed) return;
          emit(state.copyWith(
            status: PhoneAuthStatus.failure,
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
        status: PhoneAuthStatus.failure,
        errorMessage: _firebaseMsg(e),
      ));
    }
  }

  Future<void> verifyResetCode(String code) async {
    final vid = _verificationId;
    if (vid == null) {
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: 'لم يتم إرسال رمز التحقق بعد.',
      ));
      return;
    }
    emit(state.copyWith(status: PhoneAuthStatus.verifyingCode, clearError: true));
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: code,
      );
      await _captureResetToken(credential);
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: _firebaseMsg(e),
      ));
    }
  }

  Future<void> _captureResetToken(PhoneAuthCredential credential) async {
    final userCred = await _auth.signInWithCredential(credential);
    final idToken = await userCred.user?.getIdToken();
    if (idToken == null) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: 'فشل الحصول على رمز التحقق.',
      ));
      return;
    }
    _resetIdToken = idToken;
    if (isClosed) return;
    emit(state.copyWith(status: PhoneAuthStatus.codeVerified));
  }

  Future<void> submitNewPassword(String newPassword) async {
    final idToken = _resetIdToken;
    if (idToken == null) {
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: 'انتهت الجلسة، أعد المحاولة.',
      ));
      return;
    }
    emit(state.copyWith(status: PhoneAuthStatus.resetting, clearError: true));
    try {
      await _authRepo.phoneResetPassword(
        idToken: idToken,
        newPassword: newPassword,
      );
      if (isClosed) return;
      emit(state.copyWith(status: PhoneAuthStatus.resetSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  // ---------------- helpers ----------------

  void _startCooldown([int seconds = 30]) {
    _cooldownTimer?.cancel();
    emit(state.copyWith(cooldownSeconds: seconds));
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (isClosed) {
        t.cancel();
        return;
      }
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
    await CacheHelper.setSecuredString(AppConstants.token, token);
    await CacheHelper.setSecuredString(AppConstants.refreshToken, refresh);
    await CacheHelper.setSecuredString(AppConstants.userId, userId);
    // Role is read back via SharedPreferences (getString) on startup by both
    // main._initUserData and AppRouter.initialRoute, so it MUST be written with
    // setData — writing it to secure storage left kRole empty on relaunch, which
    // sent returning users to the login screen every time.
    await CacheHelper.setData(key: AppConstants.role, value: role);
    AppConstants.kToken = token;
    AppConstants.kUserId = userId;
    AppConstants.kRole = role;
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
