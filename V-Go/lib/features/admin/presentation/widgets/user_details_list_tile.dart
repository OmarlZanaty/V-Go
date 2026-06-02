import 'package:flutter/material.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

class UserDetailsListTile extends StatelessWidget {
  const UserDetailsListTile({
    required this.title,
    required this.value,
    super.key,
    this.onTap,
    this.trailing,
  });
  final String title;
  final String value;
  final VoidCallback? onTap;
  final String? trailing;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        margin: const EdgeInsets.only(top: 9,bottom: 9),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.lightWhite,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                title,
                style: AppStyle.styleRegular14.copyWith(color: AppColors.white),
              ),
            ),
            horizontalSpace(10),
            Expanded(
              child: Text(
                value,
                style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: AppStyle.styleMedium14.copyWith(
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
