import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

class DashboardInteractiveContainer extends StatelessWidget {
  const DashboardInteractiveContainer({
    required this.title,
    required this.icon,
    required this.onTap,
    super.key,
    this.width,
  });
  final double? width;
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ).copyWith(right: 10, left: 4),
        decoration: const BoxDecoration(
          color: AppColors.lightWhite,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: HugeIcon(icon: icon, color: AppColors.primary, size: 18),
            ),
            horizontalSpace(8),
            Expanded(
              child: Text(
                title,
                style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
