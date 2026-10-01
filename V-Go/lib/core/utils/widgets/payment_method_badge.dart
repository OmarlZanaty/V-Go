import 'package:flutter/material.dart';

import '../../helpers/spacing.dart';
import '../../theming/app_colors.dart';
import '../../theming/app_style.dart';

bool isVisaMethod(String? method) => (method ?? '').toLowerCase() == 'visa';

/// Arabic label for a trip's payment method ('Cash' / 'Visa').
String paymentMethodLabel(String? method) =>
    isVisaMethod(method) ? 'فيزا' : 'نقدي';

/// Clear "how is this trip paid" row, so the rider always sees cash vs. visa.
class PaymentMethodBadge extends StatelessWidget {
  const PaymentMethodBadge({required this.method, super.key});
  final String? method;

  @override
  Widget build(BuildContext context) {
    final isVisa = isVisaMethod(method);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          Icon(
            isVisa ? Icons.credit_card : Icons.payments_outlined,
            color: AppColors.primary,
            size: 22,
          ),
          horizontalSpace(10),
          Text(
            'طريقة الدفع:',
            style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
          ),
          horizontalSpace(6),
          Text(
            paymentMethodLabel(method),
            style: AppStyle.styleMedium16.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
