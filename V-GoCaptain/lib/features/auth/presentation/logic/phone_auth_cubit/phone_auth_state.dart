part of 'phone_auth_cubit.dart';

enum PhoneAuthStatus {
  initial,
  sendingCode,
  codeSent,
  codeSendFailure,
  verifying,
  loginSuccess,
  newUser,
  verifyFailure,
}

class PhoneAuthState extends Equatable {
  final PhoneAuthStatus status;
  final String phone;
  final String errorMessage;
  final int cooldownSeconds;
  final String lastCode;

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
  List<Object?> get props => [status, phone, errorMessage, cooldownSeconds, lastCode];
}
