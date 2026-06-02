import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/api/dio_factory.dart';
import '../../../../../core/cache/cache_helper.dart';
import '../../../../../core/errors/exception.dart';
import '../../../../../core/helpers/app_type.dart';
import '../../../../../core/helpers/custom_url_launcher.dart';
import '../../../../../core/helpers/navigation_handler.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../data/model/check_state_response_model.dart';
import '../../../data/model/login_response_model.dart';
import '../../../data/model/register_request_model.dart';
import '../../../data/model/reset_password_request_model.dart';
import '../../../data/repo/auth_repo.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authRepo) : super(const AuthState());

  final AuthRepo _authRepo;

  Future<void> login(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.loginLoading));
    try {
      final result = await _authRepo.login(
        email: email,
        password: password,
        deviceType: deviceType(),
        fcmToken: CacheHelper.getString(AppConstants.fcmToken),
      );
      await _cacheUserData(result);
      emit(state.copyWith(status: AuthStatus.loginSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AuthStatus.loginFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> googleLogin() async {
    emit(state.copyWith(status: AuthStatus.loginWithGoogleLoading));
    try {
      final loginResp = await _authRepo.googleLogin();

      await customUrlLauncher(
        NavigationHandler.navigatorKey.currentContext,
        loginResp.authUrl,
      );
      emit(state.copyWith(status: AuthStatus.initial));
      final timer = Timer.periodic(const Duration(seconds: 2), (t) async {
        final result = await _authRepo.checkState(state: loginResp.state);
        if (!isClosed && result.status == 'completed') {
          t.cancel();
          await _cacheUserDataFromGoogle(result);
          emit(state.copyWith(status: AuthStatus.loginWithGoogleSuccess));
        } else if (!isClosed && result.status == 'failed') {
          t.cancel();
          emit(
            state.copyWith(
              status: AuthStatus.loginWithGoogleFailure,
              errorMessage: 'حدث خطا اثناء تسجيل الدخول',
            ),
          );
        }
      });

      Future.delayed(const Duration(minutes: 5), () {
        if (timer.isActive) timer.cancel();
      });
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AuthStatus.loginWithGoogleFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> register(RegisterRequestModel registerRequestModel) async {
    emit(state.copyWith(status: AuthStatus.registerLoading));
    try {
      final result = await _authRepo.register(registerRequestModel);
      emit(state.copyWith(status: AuthStatus.registerSuccess, message: result));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AuthStatus.registerFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> forgetPassword(String email) async {
    emit(state.copyWith(status: AuthStatus.forgotPasswordLoading));
    try {
      final result = await _authRepo.forgetPassword(email);
      emit(
        state.copyWith(
          status: AuthStatus.forgotPasswordSuccess,
          message: result,
          email: email,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AuthStatus.forgotPasswordFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> otpVerification(String otp, String email, String type) async {
    emit(state.copyWith(status: AuthStatus.otpVerificationLoading));
    try {
      await _authRepo.verifyOtp(email, otp, type);
      emit(
        state.copyWith(
          status: AuthStatus.otpVerificationSuccess,
          message: 'تم تأكيد حسابك بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AuthStatus.otpVerificationFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> resendOtp(String otpType, String email) async {
    emit(state.copyWith(status: AuthStatus.resendOtpLoading));
    try {
      // otpType: available values: Register (=0) ,  ResetPassword (=1)
      final result = await _authRepo.resendOtp(email, otpType);
      emit(
        state.copyWith(status: AuthStatus.resendOtpSuccess, message: result),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AuthStatus.resendOtpFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> resetPassword(String newPassword, String email) async {
    emit(state.copyWith(status: AuthStatus.resetPasswordLoading));
    try {
      final request = ResetPasswordRequestModel(
        email: email,
        newPassword: newPassword,
      );

      final result = await _authRepo.resetPassword(request);
      emit(
        state.copyWith(
          status: AuthStatus.resetPasswordSuccess,
          message: result,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AuthStatus.resetPasswordFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> changePassword(
    String email,
    String oldPassword,
    String newPassword,
  ) async {
    emit(state.copyWith(status: AuthStatus.changePasswordLoading));
    try {
      final result = await _authRepo.changePassword(
        email,
        oldPassword,
        newPassword,
      );
      emit(
        state.copyWith(
          status: AuthStatus.changePasswordSuccess,
          message: result,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AuthStatus.changePasswordFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> logout({required String refreshToken}) async {
    emit(state.copyWith(status: AuthStatus.logoutLoading));
    try {
      await _authRepo.logout(refreshToken: refreshToken);
      _clearData();
      emit(state.copyWith(status: AuthStatus.logoutSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AuthStatus.logoutFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> _clearData() async {
    await Future.wait(<Future<void>>[
      CacheHelper.clearAllSecuredData(),
      CacheHelper.removeData(key: AppConstants.role),
      CacheHelper.removeData(key: AppConstants.gender),
    ]);
    AppConstants.kUserId = '';
    AppConstants.kRole = '';
    AppConstants.kToken = '';
  }

  Future<void> _cacheUserData(LoginResponseModel response) async {
    await Future.wait(<Future<void>>[
      CacheHelper.setSecuredString(AppConstants.userId, response.userId),
      CacheHelper.setSecuredString(AppConstants.token, response.token),
      CacheHelper.setSecuredString(
        AppConstants.refreshToken,
        response.refreshToken,
      ),
      CacheHelper.setData(key: AppConstants.role, value: response.role),
      CacheHelper.setData(key: AppConstants.gender, value: response.gender),
    ]);
    AppConstants.kUserId = response.userId;
    AppConstants.kRole = response.role;
    AppConstants.kToken = response.token;
    DioFactory.setTokenIntoHeaderAfterLogin(response.token);
  }

  Future<void> _cacheUserDataFromGoogle(
    CheckStateResponseModel response,
  ) async {
    await Future.wait(<Future<void>>[
      CacheHelper.setSecuredString(AppConstants.userId, response.user!.userId),
      CacheHelper.setSecuredString(AppConstants.token, response.user!.token),
      CacheHelper.setSecuredString(
        AppConstants.refreshToken,
        response.user!.refreshToken,
      ),
      CacheHelper.setData(key: AppConstants.role, value: response.user!.roles),
      CacheHelper.setData(
        key: AppConstants.gender,
        value: response.user!.gender,
      ),
    ]);
    AppConstants.kUserId = response.user!.userId;
    AppConstants.kRole = response.user!.roles;
    AppConstants.kToken = response.user!.token;
    DioFactory.setTokenIntoHeaderAfterLogin(response.user!.token);
  }
}
