import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../model/promotion_model.dart';

/// The rider's offers (free rides, discounts) and promo-code entry.
class PromotionRepo {
  PromotionRepo({required ApiServices apiServices}) : _api = apiServices;

  final ApiServices _api;

  Future<List<PromotionModel>> mine() async {
    final response = await _api.get(EndPoint.myPromotions);
    final data = response is Map ? (response['data'] ?? response['Data']) : response;
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((e) => PromotionModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Returns the server's Arabic confirmation; throws on a bad code.
  Future<String> redeem(String code) async {
    final response = await _api.post(
      EndPoint.redeemPromotion,
      data: {'code': code.trim()},
    );
    final msg = response is Map ? (response['message'] ?? response['Message']) : null;
    return msg?.toString() ?? 'تم تفعيل العرض على حسابك';
  }
}
