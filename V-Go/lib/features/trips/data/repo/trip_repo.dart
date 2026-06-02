import '../../../../core/utils/model/current_trip_model.dart';
import '../model/all_trips_response.dart';
import '../model/trip_model.dart';

abstract class TripRepo {
  Future<AllTripsResponse> getAllTrips({
    String? userId,
    int? pageNumber,
    int? pageSize,
  });
  Future<TripModel> getTripById({required String tripId});
  Future<String> changeTripPricePerKilometer({required double price});
  Future<String> changeDriverCommission({required int percentage});
  Future<double> getTripPricePerKilometer();
  Future<List<CurrentTripModel>> getCurrentTrips({required String userId});
}
