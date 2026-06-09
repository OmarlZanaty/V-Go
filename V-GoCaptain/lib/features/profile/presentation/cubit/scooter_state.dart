part of 'scooter_cubit.dart';

enum ScooterStatus { initial, loading, loaded, error }

class ScooterState extends Equatable {
  final ScooterStatus status;
  final DriverProfileModel? profile;
  final String? error;

  const ScooterState({
    this.status = ScooterStatus.initial,
    this.profile,
    this.error,
  });

  ScooterState copyWith({
    ScooterStatus? status,
    DriverProfileModel? profile,
    String? error,
    bool clearError = false,
  }) {
    return ScooterState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, profile, error];
}
