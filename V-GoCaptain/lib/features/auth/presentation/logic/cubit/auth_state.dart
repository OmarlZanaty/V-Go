part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Successful login (carries the user's role).
final class LoginSuccess extends AuthState {
  final String role;
  const LoginSuccess(this.role);
  @override
  List<Object?> get props => [role];
}

/// Registration accepted — an OTP was sent to [email].
final class RegisterSuccess extends AuthState {
  final String email;
  const RegisterSuccess(this.email);
  @override
  List<Object?> get props => [email];
}

/// OTP verified for the given [type] ("Register" or "ResetPassword").
final class OtpVerified extends AuthState {
  final String type;
  const OtpVerified(this.type);
  @override
  List<Object?> get props => [type];
}

/// A password-reset OTP was sent to [email].
final class ForgotOtpSent extends AuthState {
  final String email;
  const ForgotOtpSent(this.email);
  @override
  List<Object?> get props => [email];
}

final class ResetPasswordSuccess extends AuthState {
  final String message;
  const ResetPasswordSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

final class ChangePasswordSuccess extends AuthState {
  final String message;
  const ChangePasswordSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

final class OtpResent extends AuthState {
  const OtpResent();
}

final class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}
