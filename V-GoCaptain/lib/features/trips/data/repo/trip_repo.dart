import '../models/trip_model.dart';

abstract class TripRepo {
  /// All trips for the logged-in driver (history).
  Future<List<TripModel>> getMyTrips();

  /// Unassigned trips currently waiting for a driver (status == Pending).
  Future<List<TripModel>> getPendingTrips();

  /// Asks the backend to reconcile this trip's card payment with Paymob (recovers
  /// a missed webhook). Best-effort; errors are swallowed.
  Future<void> syncPayment(String tripId);
}
