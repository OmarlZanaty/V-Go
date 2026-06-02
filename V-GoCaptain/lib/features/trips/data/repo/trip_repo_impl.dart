import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../../../../core/utils/app_constants.dart';
import '../models/trip_model.dart';
import 'trip_repo.dart';

class TripRepoImpl implements TripRepo {
  final ApiServices _apiServices;
  TripRepoImpl({required ApiServices apiServices}) : _apiServices = apiServices;

  @override
  Future<List<TripModel>> getMyTrips() async {
    final response = await _apiServices.get(
      EndPoint.getTripsByUserId(AppConstants.kUserId),
      queryParameters: {'pageNumber': 1, 'pageSize': 100},
    );
    // The endpoint may return a bare list or a paginated wrapper {items|data:[...]}.
    final list = response is List
        ? response
        : (response is Map
            ? (response['items'] ?? response['data'] ?? response['Data'] ?? [])
            : []);
    return (list as List)
        .whereType<Map>()
        .map((e) => TripModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
