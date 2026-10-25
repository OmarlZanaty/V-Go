import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/api/dio_factory.dart';
import '../../../../../core/cache/cache_helper.dart';
import '../../../../../core/errors/exception.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../data/model/phone_login_response_model.dart';
import '../../../data/repo/auth_repo.dart';
import '../../../../../core/services/device_token_sync.dart';

part 'phone_auth_state.dart';

/// Rider auth: phone number + password. After the phone is entered we check
/// whether it's already registered (-> enter password) or new (-> set password
/// + profile). Forgot-password uses a backend SMS OTP.
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

  /// Back to the phone-entry step (e.g. user taps back from the password step).
  void reset() {
    _cooldownTimer?.cancel();
    _resetToken = null;
    emit(PhoneAuthState(phone: state.phone));
  }

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
      // Saved with CacheHelper.setData (SharedPreferences), not secure storage.
      final fcmToken = CacheHelper.getString(AppConstants.fcmToken);
      final result = await _authRepo.phoneLogin(
        phone: state.phone,
        password: password,
        fcmToken: fcmToken,
        deviceType: 'Android',
      );
      if (isClosed) return;
      await _cacheSession(result);
      unawaited(DeviceTokenSync.sync());
      emit(state.copyWith(status: PhoneAuthStatus.loginSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PhoneAuthStatus.failure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  /// New user: phone + the password they just set + profile data. The sign-up
  /// screen gets its own cubit, so the phone is passed in rather than read
  /// from the login screen's state.
  Future<void> register({
    required String phone,
    required String password,
    required String fullName,
    String? email,
    String? gender,
  }) async {
    emit(state.copyWith(
        status: PhoneAuthStatus.authenticating,
        phone: phone,
        clearError: true));
    try {
      // Saved with CacheHelper.setData (SharedPreferences), not secure storage.
      final fcmToken = CacheHelper.getString(AppConstants.fcmToken);
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
      unawaited(DeviceTokenSync.sync());
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
}
