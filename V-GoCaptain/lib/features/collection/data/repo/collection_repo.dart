import '../../../../core/api/api_envelope.dart';
import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../models/collection_models.dart';

/// Daily collection by wallet transfer (Collection/me/...).
class CollectionRepo {
  CollectionRepo({required ApiServices apiServices}) : _api = apiServices;

  final ApiServices _api;

  Future<MyCollection> getMine() async {
    final data = ApiEnvelope.data(await _api.get(EndPoint.collectionMe));
    return MyCollection.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Returns the saved request and the server's message (confirmed at once,
  /// waiting for the SMS, or sent to review).
  Future<(CollectionRequest, String?)> createRequest({
    required int walletId,
    required String senderPhone,
    required double amount,
  }) async {
    final response = await _api.post(
      EndPoint.collectionRequests,
      data: {
        'walletId': walletId,
        'senderPhone': senderPhone,
        'amount': amount,
      },
    );
    final data = ApiEnvelope.data(response);
    return (
      CollectionRequest.fromJson(Map<String, dynamic>.from(data as Map)),
      ApiEnvelope.message(response),
    );
  }

  Future<void> cancelRequest(int id) async {
    ApiEnvelope.data(await _api.delete(EndPoint.collectionRequest(id)));
  }
}
