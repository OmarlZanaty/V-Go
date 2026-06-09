import '../models/trip_model.dart';

abstract class TripRepo {
  /// All trips for the logged-in driver (history).
  Future<List<TripModel>> getMyTrips();

  /// Unassigned trips currently waiting for a driver (status == Pending).
  Future<List<TripModel>> getPendingTrips();
}
