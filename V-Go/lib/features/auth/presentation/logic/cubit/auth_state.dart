part of 'auth_cubit.dart';

enum AuthStatus {
  initial,

  loginLoading,
  loginSuccess,
  loginFailure,

  loginWithGoogleLoading,
  loginWithGoogleSuccess,
  loginWithGoogleFailure,
  loginWithGoogleNewUser,

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
    this.googleIdToken = '',
    this.googleName = '',
    this.googlePhoto = '',
  });

  final AuthStatus status;
  final String email;
  final String otp;
  final String errorMessage;
  final String message;
  // Carried between the first Google sign-in and the complete-profile step.
  final String googleIdToken;
  final String googleName;
  final String googlePhoto;

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? otp,
    String? errorMessage,
    String? message,
    String? googleIdToken,
    String? googleName,
    String? googlePhoto,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      otp: otp ?? this.otp,
      errorMessage: errorMessage ?? this.errorMessage,
      message: message ?? this.message,
      googleIdToken: googleIdToken ?? this.googleIdToken,
      googleName: googleName ?? this.googleName,
      googlePhoto: googlePhoto ?? this.googlePhoto,
    );
  }

  @override
  List<Object?> get props =>
      [status, email, otp, errorMessage, message, googleIdToken, googleName, googlePhoto];
}
