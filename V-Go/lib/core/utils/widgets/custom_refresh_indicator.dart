import 'package:flutter/material.dart';

import '../../theming/app_colors.dart';

class CustomRefreshIndicator extends StatelessWidget {
  const CustomRefreshIndicator({
    required this.child,
    required this.onRefresh,
    super.key,
  });
  final Widget child;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.black,
      backgroundColor: AppColors.primary,
      child: child,
    );
  }
}
