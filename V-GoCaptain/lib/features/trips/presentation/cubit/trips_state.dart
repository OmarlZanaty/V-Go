part of 'trips_cubit.dart';

enum TripsStatus { initial, loading, loaded, error }

class TripsState extends Equatable {
  final TripsStatus status;
  final List<TripModel> trips;
  final String? error;

  const TripsState({
    this.status = TripsStatus.initial,
    this.trips = const [],
    this.error,
  });

  List<TripModel> get completed => trips.where((t) => t.isCompleted).toList();

  TripsState copyWith({
    TripsStatus? status,
    List<TripModel>? trips,
    String? error,
    bool clearError = false,
  }) {
    return TripsState(
      status: status ?? this.status,
      trips: trips ?? this.trips,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, trips, error];
}
