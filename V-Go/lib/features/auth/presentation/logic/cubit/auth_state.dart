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
    this.provider = SocialLoginProvider.google,
    this.googleIdToken = '',
    this.googleName = '',
    this.googlePhoto = '',
  });

  final AuthStatus status;
  final String email;
  final String otp;
  final String errorMessage;
  final String message;
  // Shared by Google and Apple through the complete-profile step.
  final SocialLoginProvider provider;
  final String googleIdToken;
  final String googleName;
  final String googlePhoto;

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? otp,
    String? errorMessage,
    String? message,
    SocialLoginProvider? provider,
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
      provider: provider ?? this.provider,
      googleIdToken: googleIdToken ?? this.googleIdToken,
      googleName: googleName ?? this.googleName,
      googlePhoto: googlePhoto ?? this.googlePhoto,
    );
  }

  @override
  List<Object?> get props =>
      [status, email, otp, errorMessage, message, provider, googleIdToken, googleName, googlePhoto];
}
