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

  @override
  Future<void> syncPayment(String tripId) async {
    try {
      await _apiServices.get(EndPoint.paymentStatus(tripId));
    } catch (_) {
      // Best-effort: the reconcile is server-side; a failure here just means we
      // fall back to whatever getMyTrips already knows.
    }
  }

  @override
  Future<double?> getDriverCommission() async {
    try {
      final response = await _apiServices.get(EndPoint.driverCommission);
      final v = response is Map ? (response['data'] ?? response['Data']) : null;
      return v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TripModel>> getPendingTrips() async {
    final response = await _apiServices.get(EndPoint.allPendingTrips);
    final list = response is List
        ? response
        : (response is Map
            ? (response['items'] ?? response['data'] ?? response['Data'] ?? [])
            : []);
    return (list as List)
        .whereType<Map>()
        .map((e) => TripModel.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.status == 'Pending')
        .toList();
  }
}
