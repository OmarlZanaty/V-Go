import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/checkout_link.dart';
import '../../../../core/helpers/extensions.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/payment_cubit/payment_cubit.dart';
import '../../../../core/utils/model/payment_request_model.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';

/// The rider can't request a trip while an earlier refused trip is unpaid.
/// Explains why and lets them settle it by card right away.
void showOutstandingDebtDialog(BuildContext context, String message) {
  AwesomeDialog(
    context: context,
    dialogType: DialogType.noHeader,
    animType: AnimType.rightSlide,
    title: 'مديونية رحلة سابقة',
    desc: message,
    dialogBackgroundColor: AppColors.darkGrey,
    titleTextStyle: AppStyle.styleMedium18.copyWith(color: AppColors.white),
    descTextStyle: AppStyle.styleMedium14.copyWith(color: AppColors.white),
    buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
    btnOkText: 'ادفع الآن',
    btnOkOnPress: () => _payOutstandingDebt(context),
    btnCancelText: 'لاحقاً',
    btnCancelOnPress: () {},
  ).show();
}

Future<void> _payOutstandingDebt(BuildContext context) async {
  final tripCubit = context.read<RealTimeTripCubit>();
  final paymentCubit = context.read<PaymentCubit>();

  final debt = await tripCubit.getOutstandingDebt();
  if (!context.mounted) return;
  if (debt == null) {
    successToast(context, 'لا توجد مديونية', 'يمكنك طلب رحلتك الآن');
    return;
  }

  await paymentCubit.paymentRequest(
    model: PaymentRequestModel(
      userId: AppConstants.kUserId,
      tripId: debt.tripId,
      price: debt.amount.ceil(),
      currency: 'EGP',
    ),
  );
  if (!context.mounted) return;
  final payState = paymentCubit.state;
  if (!payState.status.isPaymentRequestSuccess) {
    errorToast(context, 'حدث خطا', payState.errorMessage);
    return;
  }

  final result = await context.pushNamed(
    Routes.customPaymentWebViewRoute,
    arguments: getCheckoutLink(
      clientSecret: payState.paymentResponseModel!.clientSecret,
      publicKey: payState.paymentResponseModel!.publicKey,
    ),
  );
  try {
    if (result is String && result.contains('success=')) {
      await paymentCubit.confirmCallback(result);
    } else {
      await paymentCubit.syncPayment(debt.tripId);
    }
  } catch (_) {}

  final remaining = await tripCubit.getOutstandingDebt();
  if (!context.mounted) return;
  if (remaining == null) {
    successToast(context, 'تم الدفع', 'تم سداد المديونية، اضغط موافق لطلب رحلتك');
  } else {
    errorToast(context, 'لم يكتمل الدفع', 'لم يتم سداد المديونية، حاول مرة أخرى');
  }
}
