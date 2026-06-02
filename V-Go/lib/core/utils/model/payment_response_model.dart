class PaymentResponseModel {
  final int intentionOrderId;
  final String clientSecret;
  final String publicKey;
  final String id;

  PaymentResponseModel({
    required this.intentionOrderId,
    required this.clientSecret,
    required this.publicKey,
    required this.id,
  });

  factory PaymentResponseModel.fromJson(Map<String, dynamic> json) {
    return PaymentResponseModel(
      intentionOrderId: json['intention_order_id'],
      clientSecret: json['client_secret'],
      publicKey: json['publicKey'],
      id: json['id'],
    );
  }
}