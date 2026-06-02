import 'auth_cubit.dart';

extension AuthStepX on AuthStatus {
  bool get isInitial => this == AuthStatus.initial;

  bool get isLoginLoading => this == AuthStatus.loginLoading;
  bool get isLoginSuccess => this == AuthStatus.loginSuccess;
  bool get isLoginFailure => this == AuthStatus.loginFailure;

  bool get isLoginWithGoogleLoading =>
      this == AuthStatus.loginWithGoogleLoading;
  bool get isLoginWithGoogleSuccess =>
      this == AuthStatus.loginWithGoogleSuccess;
  bool get isLoginWithGoogleFailure =>
      this == AuthStatus.loginWithGoogleFailure;

  bool get isForgotPasswordLoading => this == AuthStatus.forgotPasswordLoading;
  bool get isForgotPasswordSuccess => this == AuthStatus.forgotPasswordSuccess;
  bool get isForgotPasswordFailure => this == AuthStatus.forgotPasswordFailure;

  bool get isOtpVerificationLoading =>
      this == AuthStatus.otpVerificationLoading;
  bool get isOtpVerificationSuccess =>
      this == AuthStatus.otpVerificationSuccess;
  bool get isOtpVerificationFailure =>
      this == AuthStatus.otpVerificationFailure;

  bool get isResendOtpLoading => this == AuthStatus.resendOtpLoading;
  bool get isResendOtpSuccess => this == AuthStatus.resendOtpSuccess;
  bool get isResendOtpFailure => this == AuthStatus.resendOtpFailure;

  bool get isResetPasswordLoading => this == AuthStatus.resetPasswordLoading;
  bool get isResetPasswordSuccess => this == AuthStatus.resetPasswordSuccess;
  bool get isResetPasswordFailure => this == AuthStatus.resetPasswordFailure;

  bool get isRegisterLoading => this == AuthStatus.registerLoading;
  bool get isRegisterSuccess => this == AuthStatus.registerSuccess;
  bool get isRegisterFailure => this == AuthStatus.registerFailure;

  bool get isLogoutLoading => this == AuthStatus.logoutLoading;
  bool get isLogoutSuccess => this == AuthStatus.logoutSuccess;
  bool get isLogoutFailure => this == AuthStatus.logoutFailure;

  bool get isChangePasswordLoading => this == AuthStatus.changePasswordLoading;
  bool get isChangePasswordSuccess => this == AuthStatus.changePasswordSuccess;
  bool get isChangePasswordFailure => this == AuthStatus.changePasswordFailure;
}
