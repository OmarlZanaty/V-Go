import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../../../../core/utils/model/current_trip_model.dart';
import '../model/all_trips_response.dart';
import '../model/trip_model.dart';
import 'trip_repo.dart';

class TripRepoImpl implements TripRepo {
  final ApiServices _apiServices;
  TripRepoImpl({required ApiServices apiServices}) : _apiServices = apiServices;
  @override
  Future<AllTripsResponse> getAllTrips({
    String? userId,
    int? pageNumber,
    int? pageSize,
  }) async {
    final response = await _apiServices.get(
      userId != null ? EndPoint.getTripsByUserId(userId) : EndPoint.allTrips,
      queryParameters: pageNumber != null
          ? {'pageNumber': pageNumber, 'pageSize': pageSize}
          : null,
    );
    return AllTripsResponse.fromJson(response);
  }

  @override
  Future<TripModel> getTripById({required String tripId}) async {
    final response = await _apiServices.get(EndPoint.getTripById(tripId));
    return TripModel.fromJson(response);
  }

  @override
  Future<String> changeTripPricePerKilometer({required double price}) async {
    final response = await _apiServices.post(
      EndPoint.pricingRule,
      data: {'pricePerKillo': price},
    );
    return response['message'];
  }

  @override
  Future<double> getTripPricePerKilometer() async {
    final response = await _apiServices.get(EndPoint.getPricePerKillo);
    return response['data']['PricePerKillo']?.toDouble() ?? 0.0;
  }

  @override
  Future<List<CurrentTripModel>> getCurrentTrips({
    required String userId,
  }) async {
    final response = await _apiServices.get(
      EndPoint.getCurrentTrips,
      queryParameters: {'userId': userId},
    );
    return response
        .map<CurrentTripModel>((trip) => CurrentTripModel.fromJson(trip))
        .toList();
  }

  @override
  Future<String> changeDriverCommission({required int percentage}) async {
    final response = await _apiServices.post(
      EndPoint.driverCommission,
      queryParameters: {'commissionPercentage': percentage},
    );
    return response['message'];
  }
}
