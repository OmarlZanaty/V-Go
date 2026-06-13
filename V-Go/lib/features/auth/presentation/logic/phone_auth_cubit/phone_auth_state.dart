part of 'phone_auth_cubit.dart';

enum PhoneAuthStatus {
  initial,
  // phone + password sign-in
  checkingPhone,
  existingUser, // phone registered -> ask for password (login)
  newUser, // phone not registered -> set password + profile
  authenticating, // login or register in flight
  loginSuccess,
  failure,
  // forgot password (Firebase OTP) flow
  sendingCode,
  codeSent,
  verifyingCode,
  codeVerified, // OTP verified -> set a new password
  resetting,
  resetSuccess,
}

class PhoneAuthState extends Equatable {
  final PhoneAuthStatus status;
  final String phone;
  final String errorMessage;
  final int cooldownSeconds; // resend cooldown countdown (reset flow)

  const PhoneAuthState({
    this.status = PhoneAuthStatus.initial,
    this.phone = '',
    this.errorMessage = '',
    this.cooldownSeconds = 0,
  });

  PhoneAuthState copyWith({
    PhoneAuthStatus? status,
    String? phone,
    String? errorMessage,
    bool clearError = false,
    int? cooldownSeconds,
  }) {
    return PhoneAuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      errorMessage: clearError ? '' : (errorMessage ?? this.errorMessage),
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    );
  }

  @override
  List<Object?> get props => [status, phone, errorMessage, cooldownSeconds];
}
