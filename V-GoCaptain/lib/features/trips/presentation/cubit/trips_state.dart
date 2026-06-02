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

  List<TripModel> get completed =>
      trips.where((t) => t.isCompleted).toList();

  /// Total earnings = sum of completed trips' price.
  double get totalEarnings =>
      completed.fold(0.0, (sum, t) => sum + t.price);

  double get todayEarnings {
    final now = DateTime.now();
    return completed
        .where((t) =>
            t.createdAt != null &&
            t.createdAt!.year == now.year &&
            t.createdAt!.month == now.month &&
            t.createdAt!.day == now.day)
        .fold(0.0, (sum, t) => sum + t.price);
  }

  int get completedCount => completed.length;

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
