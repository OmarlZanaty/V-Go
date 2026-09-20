import '../../../api/api_service.dart';
import '../../../api/end_points.dart';
import '../../model/payment_request_model.dart';
import '../../model/payment_response_model.dart';
import '../../model/saved_card_model.dart';

class PaymentRepo {
  final ApiServices _apiServices;
  PaymentRepo(this._apiServices);

  Future<PaymentResponseModel> paymentRequest({
    required PaymentRequestModel model,
  }) async {
    final response = await _apiServices.post(
      EndPoint.createPaymentIntent,
      data: model.toJson(),
    );
    return PaymentResponseModel.fromJson(response);
  }

  /// Relays Paymob's signed redirect callback (the full URL, with its HMAC) to the
  /// backend, which validates it and settles the payment. Best-effort.
  Future<void> confirmCallback(String callbackUrl) async {
    try {
      await _apiServices.post(
        EndPoint.confirmCallback,
        data: {'query': callbackUrl},
      );
    } catch (_) {
      // Settlement is server-side; ignore client-side failures.
    }
  }

  /// Asks the backend to reconcile a trip's card payment with Paymob. The GET also
  /// settles a payment whose webhook was missed and notifies the captain. Best-effort.
  Future<void> syncPayment(String tripId) async {
    try {
      await _apiServices.get(EndPoint.paymentStatus(tripId));
    } catch (_) {
      // Server-side reconcile; ignore client-side failures.
    }
  }

  Future<List<SavedCardModel>> getSavedCards() async {
    final response = await _apiServices.get(EndPoint.savedCards);
    final list = (response as List?) ?? const [];
    return list
        .map((e) => SavedCardModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteSavedCard(int id) async {
    await _apiServices.delete(EndPoint.deleteSavedCard(id));
  }

  /// Starts an "add card" verification checkout; returns the checkout payload.
  Future<PaymentResponseModel> addCard() async {
    final response = await _apiServices.post(EndPoint.addCard);
    return PaymentResponseModel.fromJson(response);
  }
}
