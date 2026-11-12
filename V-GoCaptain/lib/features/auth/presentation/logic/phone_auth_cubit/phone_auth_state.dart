part of 'phone_auth_cubit.dart';

enum PhoneAuthStatus {
  initial,
  // phone + password sign-in
  checkingPhone,
  existingUser, // phone registered -> ask for password (login)
  newUser, // phone OR native sign-in new user -> set details (password only for phone)
  authenticating, // login / register / native sign-in in flight
  loginSuccess,
  failure,
  // forgot password (backend SMS OTP) flow
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
  final String lastCode; // carries the native ID token for the signup form

  final NativeAuthProvider provider;

  const PhoneAuthState({
    this.status = PhoneAuthStatus.initial,
    this.phone = '',
    this.errorMessage = '',
    this.cooldownSeconds = 0,
    this.lastCode = '',
    this.provider = NativeAuthProvider.google,
  });

  PhoneAuthState copyWith({
    PhoneAuthStatus? status,
    String? phone,
    String? errorMessage,
    bool clearError = false,
    int? cooldownSeconds,
    String? lastCode,
    NativeAuthProvider? provider,
  }) {
    return PhoneAuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      errorMessage: clearError ? '' : (errorMessage ?? this.errorMessage),
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      lastCode: lastCode ?? this.lastCode,
      provider: provider ?? this.provider,
    );
  }

  @override
  List<Object?> get props =>
      [status, phone, errorMessage, cooldownSeconds, lastCode, provider];
}
