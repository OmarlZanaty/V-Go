import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../errors/exception.dart';
import '../../model/payment_request_model.dart';
import '../../model/payment_response_model.dart';
import '../../repo/payment_repo/payment_repo.dart';

part 'payment_state.dart';

class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(this._paymentRepo) : super(const PaymentState());
  final PaymentRepo _paymentRepo;

  /// Relays Paymob's signed redirect callback to the backend to settle the payment.
  Future<void> confirmCallback(String callbackUrl) =>
      _paymentRepo.confirmCallback(callbackUrl);

  /// Called after the checkout webview closes: nudges the backend to reconcile the
  /// payment with Paymob so the captain is notified even if the webhook was missed.
  Future<void> syncPayment(String tripId) => _paymentRepo.syncPayment(tripId);

  Future<void> paymentRequest({required PaymentRequestModel model}) async {
    emit(state.copyWith(status: PaymentStatus.paymentRequestLoading));
    try {
      final response = await _paymentRepo.paymentRequest(model: model);
      emit(
        state.copyWith(
          status: PaymentStatus.paymentRequestSuccess,
          paymentResponseModel: response,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: PaymentStatus.paymentRequestFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }
}
