part of 'auth_cubit.dart';

enum AuthStatus {
  initial,

  loginLoading,
  loginSuccess,
  loginFailure,

  loginWithGoogleLoading,
  loginWithGoogleSuccess,
  loginWithGoogleFailure,

  forgotPasswordLoading,
  forgotPasswordSuccess,
  forgotPasswordFailure,

  otpVerificationLoading,
  otpVerificationSuccess,
  otpVerificationFailure,

  resendOtpLoading,
  resendOtpSuccess,
  resendOtpFailure,

  resetPasswordLoading,
  resetPasswordSuccess,
  resetPasswordFailure,

  changePasswordLoading,
  changePasswordSuccess,
  changePasswordFailure,

  registerLoading,
  registerSuccess,
  registerFailure,

  logoutLoading,
  logoutSuccess,
  logoutFailure,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.email = '',
    this.otp = '',
    this.errorMessage = '',
    this.message = '',
  });

  final AuthStatus status;
  final String email;
  final String otp;
  final String errorMessage;
  final String message;

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? otp,
    String? errorMessage,
    String? message,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      otp: otp ?? this.otp,
      errorMessage: errorMessage ?? this.errorMessage,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, email, otp, errorMessage, message];
}
