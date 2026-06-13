import '../../../api/api_service.dart';
import '../../../api/end_points.dart';
import '../../model/payment_request_model.dart';
import '../../model/payment_response_model.dart';

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
}
