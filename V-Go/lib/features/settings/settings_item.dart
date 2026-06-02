import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theming/app_colors.dart';
import '../../core/theming/app_style.dart';

class SettingsItem extends StatelessWidget {
  const SettingsItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    super.key,
    this.trailingWidget,
  });
  final String title;
  final IconData icon;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      horizontalTitleGap: 14,
      title: Text(
        title,
        style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
      ),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.18),
        radius: 24,
        child: HugeIcon(icon: icon, color: AppColors.primary),
      ),
      trailing:
          trailingWidget ??
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 18,
            color: Colors.grey[700],
          ),
    );
  }
}
