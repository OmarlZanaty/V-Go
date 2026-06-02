import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theming/app_colors.dart';
import '../../theming/app_style.dart';

class CustomFailureWidget extends StatelessWidget {
  const CustomFailureWidget({
    required this.text,
    super.key,
    this.textColor,
    this.onRetry,
  });
  final String text;
  final Color? textColor;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    return onRetry != null
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: AppStyle.styleMedium16.copyWith(
                    color: textColor ?? AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(width: 1.sw, height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  label: Text('اعادة المحاولة', style: AppStyle.styleMedium14),
                  icon: const Icon(Icons.refresh, color: AppColors.black),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                  ),
                ),
              ],
            ),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.lightWhite,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  text,
                  style: AppStyle.styleMedium16.copyWith(
                    color: textColor ?? AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
  }
}
