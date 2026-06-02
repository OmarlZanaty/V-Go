import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/api/dio_factory.dart';
import '../../../../../core/cache/cache_helper.dart';
import '../../../../../core/errors/exception.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../data/model/login_response_model.dart';
import '../../../data/model/register_request_model.dart';
import '../../../data/model/reset_password_request_model.dart';
import '../../../data/repo/auth_repo.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo _authRepo;
  AuthCubit(this._authRepo) : super(const AuthInitial());

  // ---------- Login ----------
  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      emit(const AuthError('برجاء إدخال البريد الإلكتروني وكلمة المرور'));
      return;
    }
    emit(const AuthLoading());
    try {
      final fcmToken = await CacheHelper.getSecuredString(AppConstants.fcmToken);
      final result = await _authRepo.login(
        email: email.trim(),
        password: password,
        fcmToken: fcmToken,
        deviceType: AppConstants.deviceType,
      );
      if (result.role != AppConstants.driverRole) {
        emit(const AuthError('هذا التطبيق مخصص للكباتن فقط'));
        return;
      }
      await _persistSession(result);
      emit(LoginSuccess(result.role));
    } on ServerFailure catch (f) {
      emit(AuthError(f.errMessage));
    } catch (e) {
      emit(AuthError(ServerFailure.fromError(e).errMessage));
    }
  }

  // ---------- Register (driver signup) ----------
  Future<void> register(RegisterRequestModel model) async {
    emit(const AuthLoading());
    try {
      await _authRepo.register(model);
      emit(RegisterSuccess(model.email));
    } on ServerFailure catch (f) {
      emit(AuthError(f.errMessage));
    } catch (e) {
      emit(AuthError(ServerFailure.fromError(e).errMessage));
    }
  }

  // ---------- OTP ----------
  Future<void> verifyOtp({
    required String email,
    required String otp,
    required String type, // "Register" or "ResetPassword"
  }) async {
    emit(const AuthLoading());
    try {
      await _authRepo.verifyOtp(email, otp, type);
      emit(OtpVerified(type));
    } on ServerFailure catch (f) {
      emit(AuthError(f.errMessage));
    } catch (e) {
      emit(AuthError(ServerFailure.fromError(e).errMessage));
    }
  }

  Future<void> resendOtp({required String email, required String type}) async {
    try {
      await _authRepo.resendOtp(email, type);
      emit(const OtpResent());
    } on ServerFailure catch (f) {
      emit(AuthError(f.errMessage));
    } catch (e) {
      emit(AuthError(ServerFailure.fromError(e).errMessage));
    }
  }

  // ---------- Forgot / Reset ----------
  Future<void> forgetPassword(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      emit(const AuthError('برجاء إدخال بريد إلكتروني صالح'));
      return;
    }
    emit(const AuthLoading());
    try {
      await _authRepo.forgetPassword(email.trim());
      emit(ForgotOtpSent(email.trim()));
    } on ServerFailure catch (f) {
      emit(AuthError(f.errMessage));
    } catch (e) {
      emit(AuthError(ServerFailure.fromError(e).errMessage));
    }
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    emit(const AuthLoading());
    try {
      final msg = await _authRepo.resetPassword(
        ResetPasswordRequestModel(email: email, newPassword: newPassword),
      );
      emit(ResetPasswordSuccess(msg));
    } on ServerFailure catch (f) {
      emit(AuthError(f.errMessage));
    } catch (e) {
      emit(AuthError(ServerFailure.fromError(e).errMessage));
    }
  }

  // ---------- Change password ----------
  Future<void> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    emit(const AuthLoading());
    try {
      final msg = await _authRepo.changePassword(email, oldPassword, newPassword);
      emit(ChangePasswordSuccess(msg));
    } on ServerFailure catch (f) {
      emit(AuthError(f.errMessage));
    } catch (e) {
      emit(AuthError(ServerFailure.fromError(e).errMessage));
    }
  }

  Future<void> _persistSession(LoginResponseModel result) async {
    await CacheHelper.setSecuredString(AppConstants.token, result.token);
    await CacheHelper.setSecuredString(
      AppConstants.refreshToken,
      result.refreshToken,
    );
    await CacheHelper.setSecuredString(AppConstants.userId, result.userId);
    await CacheHelper.setData(key: AppConstants.role, value: result.role);
    await CacheHelper.setData(key: AppConstants.userName, value: result.name);
    await CacheHelper.setData(
        key: AppConstants.profileImage, value: result.profilePicture);
    AppConstants.kToken = result.token;
    AppConstants.kUserId = result.userId;
    AppConstants.kRole = result.role;
    AppConstants.kUserName = result.name;
    AppConstants.kProfileImage = result.profilePicture;
    await DioFactory.setTokenIntoHeaderAfterLogin(result.token);
  }
}
