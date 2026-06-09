import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

/// A single tappable settings row (mirrors the rider app's SettingsItem).
class SettingsItem extends StatelessWidget {
  const SettingsItem({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.color,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.white;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        leading: CircleAvatar(
          radius: 22.r,
          backgroundColor: (color ?? AppColors.primary).withValues(alpha: 0.18),
          child: Icon(icon, color: color ?? AppColors.primary, size: 22.r),
        ),
        title: Text(title, style: AppStyle.body.copyWith(color: c)),
        trailing: trailing ??
            Icon(Icons.chevron_left, color: AppColors.grey, size: 22.r),
      ),
    );
  }
}

/// Section title between groups of settings rows.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(top: 16.h, bottom: 8.h, right: 6.w),
        child: Text(
          title,
          style: AppStyle.body.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
