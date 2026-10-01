import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theming/app_colors.dart';
import '../theming/app_style.dart';

bool isVisaMethod(String? method) => (method ?? '').toLowerCase() == 'visa';

/// Arabic label for a trip's payment method ('Cash' / 'Visa').
String paymentMethodLabel(String? method) =>
    isVisaMethod(method) ? 'فيزا' : 'نقدي';

/// Clear "how is this trip paid" row, so the captain knows whether to collect
/// cash or wait for the client's card payment.
class PaymentMethodBadge extends StatelessWidget {
  const PaymentMethodBadge({super.key, required this.method});
  final String? method;

  @override
  Widget build(BuildContext context) {
    final isVisa = isVisaMethod(method);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.primary, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(isVisa ? Icons.credit_card : Icons.payments_outlined,
              color: AppColors.primary, size: 22.r),
          SizedBox(width: 10.w),
          Text('طريقة الدفع:', style: AppStyle.body),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              isVisa ? 'فيزا (دفع إلكتروني)' : 'نقدي (حصّل من العميل)',
              style: AppStyle.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
