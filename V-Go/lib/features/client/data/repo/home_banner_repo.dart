import 'dart:convert';

import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../../../../core/cache/cache_helper.dart';
import '../model/home_banner_model.dart';

/// Home carousel banners. The last server list is cached so the carousel shows
/// instantly on the next launch (and offline).
class HomeBannerRepo {
  HomeBannerRepo({required ApiServices apiServices}) : _api = apiServices;

  final ApiServices _api;
  static const String _cacheKey = 'home_banners_cache';

  List<HomeBannerModel>? cached() {
    final raw = CacheHelper.getString(_cacheKey);
    if (raw.isEmpty) return null;
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => HomeBannerModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<HomeBannerModel>> fetch() async {
    final response = await _api.get(EndPoint.activeBanners);
    final data = response is Map
        ? (response['data'] ?? response['Data'])
        : response;
    final banners = (data as List? ?? const [])
        .whereType<Map>()
        .map((e) => HomeBannerModel.fromJson(Map<String, dynamic>.from(e)))
        .where((b) => b.imageUrl.isNotEmpty)
        .toList();
    await CacheHelper.setData(
      key: _cacheKey,
      value: jsonEncode(banners.map((b) => b.toJson()).toList()),
    );
    return banners;
  }

  /// Best-effort tap counter for the advertiser report.
  Future<void> recordClick(int id) async {
    try {
      await _api.post(EndPoint.bannerClick(id));
    } catch (_) {}
  }
}
