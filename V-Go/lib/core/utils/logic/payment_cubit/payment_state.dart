part of 'payment_cubit.dart';

enum PaymentStatus {
  initial,
  paymentRequestLoading,
  paymentRequestSuccess,
  paymentRequestFailure,

}

extension PaymentStatusExtension on PaymentStatus {
  bool get isInitial => this == PaymentStatus.initial;
  bool get isPaymentRequestLoading =>
      this == PaymentStatus.paymentRequestLoading;
  bool get isPaymentRequestSuccess =>
      this == PaymentStatus.paymentRequestSuccess;
  bool get isPaymentRequestFailure =>
      this == PaymentStatus.paymentRequestFailure;
}

class PaymentState extends Equatable {
  final PaymentStatus status;
  final String errorMessage;
  final PaymentResponseModel? paymentResponseModel;
  const PaymentState({
    this.status = PaymentStatus.initial,
    this.errorMessage = '',
    this.paymentResponseModel,
  });

  PaymentState copyWith({
    PaymentStatus? status,
    String? errorMessage,
    PaymentResponseModel? paymentResponseModel,
  }) {
    return PaymentState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      paymentResponseModel: paymentResponseModel ?? this.paymentResponseModel,
    );
  }

  @override
  List<Object> get props => [status, errorMessage];
}
