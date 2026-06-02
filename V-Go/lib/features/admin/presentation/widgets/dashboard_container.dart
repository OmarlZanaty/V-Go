import 'package:flutter/material.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

class DashboardContainer extends StatelessWidget {
  const DashboardContainer({
    required this.title,
    required this.value,
    this.onTap,
    super.key,
    this.width,
    this.valueTextStyle,
  });
  final String title;
  final String value;
  final VoidCallback? onTap;
  final double? width;
  final TextStyle? valueTextStyle;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        width: width,
        padding: const EdgeInsets.only(top: 10, bottom: 2, left: 16, right: 16),
        decoration: const BoxDecoration(
          color: AppColors.lightWhite,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppStyle.styleRegular14.copyWith(color: AppColors.white)),
            verticalSpace(6),
            Text(value, style: valueTextStyle ?? AppStyle.styleBold24.copyWith(color: AppColors.white)),
          ],
        ),
      ),
    );
  }
}
