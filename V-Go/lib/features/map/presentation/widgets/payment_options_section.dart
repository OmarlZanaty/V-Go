import 'dart:developer';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/checkout_link.dart';
import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/payment_cubit/payment_cubit.dart';
import '../../../../core/utils/model/current_trip_model.dart';
import '../../../../core/utils/model/payment_request_model.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_extension.dart';

/// Payment area shown during/after the ride. Renders ONLY the method the rider
/// already chose when requesting the trip (cash OR card) — no switching mid-ride.
/// Auto-hides once the payment lands (paymentStatus == 'Paid').
Widget paymentOptionsSection(
  BuildContext context,
  RealTimeTripState tripState, {
  CurrentTripModel? currentTrip,
}) {
  return BlocConsumer<RealTimeTripCubit, RealTimeTripState>(
    listener: (context, state) {
      if (state.status.isPayTripInCashSuccess) {
        context.pop();
        AwesomeDialog(
          context: context,
          dialogType: DialogType.noHeader,
          animType: AnimType.rightSlide,
          title: 'الدفع نقدي',
          desc: 'يرجي دفع الرحلة للسائق لبدأ الرحلة',
          dialogBackgroundColor: AppColors.darkGrey,
          titleTextStyle: AppStyle.styleMedium18.copyWith(
            color: AppColors.white,
          ),
          descTextStyle: AppStyle.styleMedium14.copyWith(
            color: AppColors.white,
          ),
          btnOkOnPress: () {},
          btnOkText: 'موافق',
          buttonsTextStyle: AppStyle.styleMedium14.copyWith(
            color: Colors.white,
          ),
        ).show();
        log(state.paymentStatusModel?.paymentStatus ?? '');
      } else if (state.status.isPayTripInCashFailure) {
        context.pop();
        errorToast(context, 'حدث خطا', state.errorMessage);
      } else if (state.status.isPayTripInCashLoading) {
        loadingDialog(context);
      }
    },
    builder: (context, state) {
      if (state.paymentStatusModel?.paymentStatus == 'Paid') {
        return const SizedBox.shrink();
      }
      // Read the chosen method from the freshest server trip first (the live
      // currentTrip carries the real PaymentMethod); fall back to the passed one.
      final trip = state.currentTrip ?? currentTrip;
      final isVisa = (trip?.paymentMethod ?? 'Cash').toLowerCase() == 'visa';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          verticalSpace(16),
          Text(
            isVisa ? 'الدفع إلكترونياً' : 'الدفع نقداً',
            style: AppStyle.styleMedium14,
          ),
          verticalSpace(10),
          isVisa
              ? _electronicTile(context, tripState, currentTrip: trip)
              : _cashTile(context),
        ],
      );
    },
  );
}

// Cash: the captain confirms receipt; guide the rider, no self-serve action.
Widget _cashTile(BuildContext context) {
  return InkWell(
    onTap: () {
      successToast(
        context,
        'الدفع نقداً',
        'سلّم المبلغ للسائق وسيؤكد الاستلام لإنهاء الرحلة',
      );
    },
    borderRadius: const BorderRadius.all(Radius.circular(12)),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'نقدي',
            style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
          ),
          Image.asset('assets/images/cash.png', width: 34),
        ],
      ),
    ),
  );
}

// Card: opens the Paymob unified-checkout webview.
Widget _electronicTile(
  BuildContext context,
  RealTimeTripState tripState, {
  CurrentTripModel? currentTrip,
}) {
  return BlocConsumer<PaymentCubit, PaymentState>(
    listenWhen: (p, c) => _buildAndListenPaymentWhen(c),
    buildWhen: (p, c) => _buildAndListenPaymentWhen(c),
    listener: (context, state) {
      if (state.status.isPaymentRequestSuccess) {
        context.pushNamed(
          Routes.customPaymentWebViewRoute,
          arguments: getCheckoutLink(
            clientSecret: state.paymentResponseModel!.clientSecret,
            publicKey: state.paymentResponseModel!.publicKey,
          ),
        );
      } else if (state.status.isPaymentRequestFailure) {
        errorToast(context, 'حدث خطا', state.errorMessage);
      }
    },
    builder: (context, state) {
      return state.status.isPaymentRequestLoading
          ? const CustomLoadingWidget()
          : InkWell(
              onTap: () {
                _createPaymentRequestModel(
                  context,
                  tripState,
                  currentTrip: currentTrip,
                );
              },
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.lightWhite,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الكتروني',
                      style: AppStyle.styleMedium14
                          .copyWith(color: AppColors.white),
                    ),
                    Image.asset('assets/images/wallet.png', width: 34),
                  ],
                ),
              ),
            );
    },
  );
}

bool _buildAndListenPaymentWhen(PaymentState state) {
  return state.status.isPaymentRequestLoading ||
      state.status.isPaymentRequestSuccess ||
      state.status.isPaymentRequestFailure;
}

void _createPaymentRequestModel(
  BuildContext context,
  RealTimeTripState tripState, {
  CurrentTripModel? currentTrip,
}) {
  context.read<PaymentCubit>().paymentRequest(
    model: PaymentRequestModel(
      userId: AppConstants.kUserId,
      tripId: currentTrip?.tripId ?? tripState.tripId,
      price: currentTrip?.price.ceil() ?? tripState.tripPrice.ceil(),
      currency: 'EGP',
    ),
  );
}
