import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../../core/api/dio_factory.dart';
import '../../../../../core/cache/cache_helper.dart';
import '../../../../../core/errors/exception.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../data/model/phone_login_response_model.dart';
import '../../../data/repo/auth_repo.dart';

part 'phone_auth_state.dart';

/// Captain auth: phone number + password (Google sign-in kept). After the phone
/// is entered we check whether it's a registered captain (-> enter password) or
/// new (-> set password + driver details). Forgot-password uses a backend SMS
/// OTP. Google sign-in leaves [phone] empty so the sign-up screen
/// can tell a Google sign-up (no password) from a phone sign-up.
class PhoneAuthCubit extends Cubit<PhoneAuthState> {
  PhoneAuthCubit(this._authRepo) : super(const PhoneAuthState());

  final AuthRepo _authRepo;
  String? _resetToken;
  Timer? _cooldownTimer;

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }

  void reset() {
    _cooldownTimer?.cancel();
    _resetToken = null;
    emit(PhoneAuthState(phone: state.phone));
  }

  // ---------------- phone + password ----------------

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

  Future<void> login(String password) async {
    emit(state.copyWith(
        status: PhoneAuthStatus.authenticating, clearError: true));
    try {
      final result = await _authRepo.phoneLogin(
        phone: state.phone,
        password: password,
        fcmToken:
            (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '',
        deviceType: AppConstants.deviceType,
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

  Future<void> registerDriver({
    required String password,
    required String fullName,
    String? email,
    String? gender,
    String? nationalId,
    String? driverLicense,
    required int scooterType,
    String? scooterLicense,
  }) async {
    emit(state.copyWith(
        status: PhoneAuthStatus.authenticating, clearError: true));
    try {
      final result = await _authRepo.phoneRegisterDriver(
        phone: state.phone,
        password: password,
        fullName: fullName,
        email: email,
        gender: gender,
        nationalId: nationalId,
        driverLicense: driverLicense,
        scooterType: scooterType,
        scooterLicense: scooterLicense,
        fcmToken:
            (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '',
        deviceType: AppConstants.deviceType,
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

  // ---------------- forgot password (backend SMS OTP) ----------------

  Future<void> sendResetCode(String rawPhone) async {
    final phone = _toE164(rawPhone);
    if (state.status == PhoneAuthStatus.sendingCode ||
        (state.phone == phone && state.cooldownSeconds > 0)) {
      return;
    }
    _cooldownTimer?.cancel();
    _resetToken = null;
    emit(state.copyWith(
      status: PhoneAuthStatus.sendingCode,
      phone: phone,
      clearError: true,
      cooldownSeconds: 0,
    ));
    try {
      final seconds = await _authRepo.phoneResetRequest(phone: phone);
      if (isClosed) return;
      emit(state.copyWith(status: PhoneAuthStatus.codeSent));
      _startCooldown(seconds);
    } catch (e) {
      if (isClosed) return;
      if (e is DioException && e.response?.statusCode == 429) {
        final response = e.response?.data;
        if (response is Map && response['code'] == 'COOLDOWN') {
          final data = response['data'];
          final seconds = data is Map ? data['cooldownSeconds'] : null;
          _startCooldown(
            seconds is num && seconds >= 0 ? seconds.toInt() : 60,
          );
        }
      }
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  Future<void> verifyResetCode(String code) async {
    if (state.phone.isEmpty) {
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: 'لم يتم إرسال رمز التحقق بعد.',
      ));
      return;
    }
    emit(state.copyWith(status: PhoneAuthStatus.verifyingCode, clearError: true));
    try {
      final resetToken = await _authRepo.phoneResetVerify(
        phone: state.phone,
        code: code,
      );
      if (isClosed) return;
      _resetToken = resetToken;
      emit(state.copyWith(status: PhoneAuthStatus.codeVerified));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  Future<void> submitNewPassword(String newPassword) async {
    final resetToken = _resetToken;
    if (resetToken == null) {
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: 'انتهت الجلسة، أعد المحاولة.',
      ));
      return;
    }
    emit(state.copyWith(status: PhoneAuthStatus.resetting, clearError: true));
    try {
      await _authRepo.phoneResetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      if (isClosed) return;
      _resetToken = null;
      _cooldownTimer?.cancel();
      emit(state.copyWith(
        status: PhoneAuthStatus.resetSuccess,
        cooldownSeconds: 0,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  // ---------------- Google sign-in (kept) ----------------

  /// Google Sign-In for captain. New users (not yet drivers) are routed to the
  /// driver sign-up form; the Google ID token is carried in [lastCode] and
  /// [phone] is left empty so the form knows to skip the password.
  Future<void> googleSignIn() async {
    emit(state.copyWith(
        status: PhoneAuthStatus.authenticating, clearError: true));
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
          status: PhoneAuthStatus.failure,
          errorMessage: 'فشل الحصول على رمز Google.',
        ));
        return;
      }
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
          // Carry the Google ID token; keep phone empty to flag a Google sign-up.
          lastCode: idToken,
          phone: '',
        ));
      } else {
        await _cacheSession(result);
        emit(state.copyWith(status: PhoneAuthStatus.loginSuccess));
      }
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  Future<void> registerDriverWithGoogle({
    required String fullName,
    required String phone,
    String? email,
    String? gender,
    String? nationalId,
    String? driverLicense,
    required int scooterType,
    String? scooterLicense,
  }) async {
    emit(state.copyWith(
        status: PhoneAuthStatus.authenticating, clearError: true));
    try {
      final fcmToken =
          (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '';
      final result = await _authRepo.googleTokenDriver(
        idToken: state.lastCode, // lastCode holds the Google ID token
        fullName: fullName,
        phone: phone,
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
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  // ---------------- helpers ----------------

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    emit(state.copyWith(cooldownSeconds: seconds));
    if (seconds <= 0) return;
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
}
