class PaymentStatusModel {
  final String paymentStatus;
  final String paymentMessage;

  PaymentStatusModel({
    required this.paymentMessage,
    this.paymentStatus = 'Pending',
  });

  factory PaymentStatusModel.fromJson(Map<String, dynamic> json) {
    return PaymentStatusModel(
      paymentStatus: json['status'],
      paymentMessage: json['message'],
    );
  }
}
