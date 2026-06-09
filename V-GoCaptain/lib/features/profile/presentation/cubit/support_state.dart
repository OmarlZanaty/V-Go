part of 'support_cubit.dart';

enum SupportStatus { initial, submitting, success, error }

class SupportState extends Equatable {
  final SupportStatus status;
  final String? error;

  const SupportState({this.status = SupportStatus.initial, this.error});

  SupportState copyWith({
    SupportStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return SupportState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, error];
}
