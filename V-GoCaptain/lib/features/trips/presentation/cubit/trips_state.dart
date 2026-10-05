part of 'trips_cubit.dart';

enum TripsStatus { initial, loading, loaded, error }

class TripsState extends Equatable {
  final TripsStatus status;
  final List<TripModel> trips;
  final String? error;

  /// Captain's share of each fare in percent; null until fetched (then the
  /// full fare is shown, matching the backend's own fallback).
  final double? commissionPct;

  const TripsState({
    this.status = TripsStatus.initial,
    this.trips = const [],
    this.error,
    this.commissionPct,
  });

  /// What the captain actually earns from [t] after the app's cut.
  double shareOf(TripModel t) => t.price * (commissionPct ?? 100) / 100;

  List<TripModel> get completed =>
      trips.where((t) => t.isCompleted).toList();

  /// Completed trips whose money is in (cash collected, or card settled).
  List<TripModel> get paid => trips.where((t) => t.isSettled).toList();

  /// Total earnings = captain's share of every settled trip.
  double get totalEarnings => paid.fold(0.0, (sum, t) => sum + shareOf(t));

  double get todayEarnings {
    final now = DateTime.now();
    return paid
        .where((t) =>
            t.createdAt != null &&
            t.createdAt!.year == now.year &&
            t.createdAt!.month == now.month &&
            t.createdAt!.day == now.day)
        .fold(0.0, (sum, t) => sum + shareOf(t));
  }

  int get completedCount => completed.length;

  TripsState copyWith({
    TripsStatus? status,
    List<TripModel>? trips,
    String? error,
    bool clearError = false,
    double? commissionPct,
  }) {
    return TripsState(
      status: status ?? this.status,
      trips: trips ?? this.trips,
      error: clearError ? null : (error ?? this.error),
      commissionPct: commissionPct ?? this.commissionPct,
    );
  }

  @override
  List<Object?> get props => [status, trips, error, commissionPct];
}
