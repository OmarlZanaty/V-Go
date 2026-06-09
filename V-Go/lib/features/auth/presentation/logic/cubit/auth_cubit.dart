import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../../core/api/dio_factory.dart';
import '../../../../../core/cache/cache_helper.dart';
import '../../../../../core/errors/exception.dart';
import '../../../../../core/helpers/app_type.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../data/model/login_response_model.dart';
import '../../../data/model/phone_login_response_model.dart';
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
      const webClientId =
          '792221536894-jqrpntom44mkat6kfn1lj916g5lp79a0.apps.googleusercontent.com';
      final googleSignIn = GoogleSignIn(serverClientId: webClientId);

      // Sign out first so the account picker always appears.
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled the picker.
        if (isClosed) return;
        emit(state.copyWith(status: AuthStatus.initial));
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (isClosed) return;
        emit(state.copyWith(
          status: AuthStatus.loginWithGoogleFailure,
          errorMessage: 'فشل الحصول على رمز Google.',
        ));
        return;
      }

      final fcmToken =
          (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '';
      final result = await _authRepo.googleTokenLogin(
        idToken: idToken,
        fcmToken: fcmToken,
        deviceType: 'Android',
      );

      if (isClosed) return;
      if (result.isNewUser) {
        // New account — collect the required profile (name + phone) before creating it.
        emit(state.copyWith(
          status: AuthStatus.loginWithGoogleNewUser,
          googleIdToken: idToken,
          googleName: result.name ?? account.displayName ?? '',
          googlePhoto: result.profilePicture ?? account.photoUrl ?? '',
        ));
      } else {
        await _cacheUserDataFromGoogle(result);
        emit(state.copyWith(status: AuthStatus.loginWithGoogleSuccess));
      }
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: AuthStatus.loginWithGoogleFailure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  /// Completes a new Google account after the user fills the required profile
  /// (full name + phone; photo optional, defaults to the Google photo).
  Future<void> completeGoogleProfile({
    required String idToken,
    required String fullName,
    required String phone,
    String? gender,
    String? profilePicture,
  }) async {
    emit(state.copyWith(status: AuthStatus.loginWithGoogleLoading));
    try {
      final fcmToken =
          (await CacheHelper.getSecuredString(AppConstants.fcmToken)) ?? '';
      final result = await _authRepo.googleTokenLogin(
        idToken: idToken,
        fullName: fullName,
        phone: phone,
        gender: gender,
        profilePicture: profilePicture,
        fcmToken: fcmToken,
        deviceType: 'Android',
      );
      if (isClosed) return;
      await _cacheUserDataFromGoogle(result);
      emit(state.copyWith(status: AuthStatus.loginWithGoogleSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: AuthStatus.loginWithGoogleFailure,
        errorMessage: ServerFailure.fromError(e).errMessage,
      ));
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
      await _authRepo.verifyEmailOtp(email, otp, type);
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
    PhoneLoginResponseModel response,
  ) async {
    final userId = response.userId ?? '';
    final token = response.token ?? '';
    final refresh = response.refreshToken ?? '';
    final role = response.role ?? '';
    final gender = response.gender ?? '';
    await Future.wait(<Future<void>>[
      CacheHelper.setSecuredString(AppConstants.userId, userId),
      CacheHelper.setSecuredString(AppConstants.token, token),
      CacheHelper.setSecuredString(AppConstants.refreshToken, refresh),
      CacheHelper.setData(key: AppConstants.role, value: role),
      CacheHelper.setData(key: AppConstants.gender, value: gender),
    ]);
    AppConstants.kUserId = userId;
    AppConstants.kRole = role;
    AppConstants.kToken = token;
    DioFactory.setTokenIntoHeaderAfterLogin(token);
  }
}
