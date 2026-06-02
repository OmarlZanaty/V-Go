import '../models/trip_model.dart';

abstract class TripRepo {
  /// All trips for the logged-in driver (history).
  Future<List<TripModel>> getMyTrips();
}
