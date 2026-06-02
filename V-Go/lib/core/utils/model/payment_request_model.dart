class PaymentRequestModel {
  final String userId;
  final String tripId;
  final int price;
  final String currency;

  PaymentRequestModel({
    required this.userId,
    required this.tripId,
    required this.price,
    required this.currency,
  });
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'tripId': tripId,
      'price': price,
      'currency': currency,
    };
  }
}
