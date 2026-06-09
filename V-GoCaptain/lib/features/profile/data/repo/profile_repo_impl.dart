import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../../../../core/utils/app_constants.dart';
import '../models/driver_profile_model.dart';
import '../models/rating_model.dart';
import 'profile_repo.dart';

class ProfileRepoImpl implements ProfileRepo {
  final ApiServices _api;
  ProfileRepoImpl({required ApiServices apiServices}) : _api = apiServices;

  @override
  Future<DriverProfileModel> getProfile() async {
    final res = await _api.get(EndPoint.getDriverProfile(AppConstants.kUserId));
    // Endpoint returns the DTO directly, but tolerate a {data:{...}} wrapper.
    final map = res is Map && res['data'] is Map ? res['data'] : res;
    return DriverProfileModel.fromJson(Map<String, dynamic>.from(map as Map));
  }

  @override
  Future<List<RatingModel>> getMyRatings() async {
    final res = await _api.get(EndPoint.getUserRates(AppConstants.kUserId));
    final list = res is List
        ? res
        : (res is Map ? (res['data'] ?? res['items'] ?? res['Data'] ?? []) : []);
    return (list as List)
        .whereType<Map>()
        .map((e) => RatingModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<void> sendSupportReport(String content) async {
    final userId = AppConstants.kUserId;

    // 1) Ensure a support chat exists for this driver.
    String? chatId;
    try {
      final chatRes = await _api.post(
        EndPoint.createSupportChat,
        queryParameters: {'clientId': userId},
      );
      chatId = _extractId(chatRes);
    } catch (_) {
      // If chat creation fails, still try to send (backend may create one).
    }

    // 2) Post the report message.
    await _api.post(
      EndPoint.sendSupportMessage,
      queryParameters: {
        if (chatId != null && chatId.isNotEmpty) 'chatId': chatId,
        'senderId': userId,
        'content': content,
      },
    );
  }

  String? _extractId(dynamic res) {
    if (res == null) return null;
    if (res is String) return res;
    if (res is Map) {
      final v = res['id'] ??
          res['chatId'] ??
          res['Id'] ??
          res['ChatId'] ??
          (res['data'] is Map ? res['data']['id'] : null);
      return v?.toString();
    }
    return null;
  }
}
