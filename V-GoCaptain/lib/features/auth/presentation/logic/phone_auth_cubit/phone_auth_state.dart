part of 'phone_auth_cubit.dart';

enum PhoneAuthStatus {
  initial,
  // phone + password sign-in
  checkingPhone,
  existingUser, // phone registered -> ask for password (login)
  newUser, // phone OR google new user -> set details (password only for phone)
  authenticating, // login / register / google in flight
  loginSuccess,
  failure,
  // forgot password (Firebase OTP) flow
  sendingCode,
  codeSent,
  verifyingCode,
  codeVerified,
  resetting,
  resetSuccess,
}

class PhoneAuthState extends Equatable {
  final PhoneAuthStatus status;
  final String phone;
  final String errorMessage;
  final int cooldownSeconds;
  final String lastCode; // carries the Google ID token for the signup form

  const PhoneAuthState({
    this.status = PhoneAuthStatus.initial,
    this.phone = '',
    this.errorMessage = '',
    this.cooldownSeconds = 0,
    this.lastCode = '',
  });

  PhoneAuthState copyWith({
    PhoneAuthStatus? status,
    String? phone,
    String? errorMessage,
    bool clearError = false,
    int? cooldownSeconds,
    String? lastCode,
  }) {
    return PhoneAuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      errorMessage: clearError ? '' : (errorMessage ?? this.errorMessage),
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      lastCode: lastCode ?? this.lastCode,
    );
  }

  @override
  List<Object?> get props =>
      [status, phone, errorMessage, cooldownSeconds, lastCode];
}
