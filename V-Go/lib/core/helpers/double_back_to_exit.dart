// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../theming/app_colors.dart';
import '../theming/app_style.dart';

class DoubleBackToExitWrapper extends StatefulWidget {
  final Widget child;

  const DoubleBackToExitWrapper({required this.child, super.key});

  @override
  State<DoubleBackToExitWrapper> createState() =>
      _DoubleBackToExitWrapperState();
}

class _DoubleBackToExitWrapperState extends State<DoubleBackToExitWrapper> {
  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_lastPressedAt == null ||
            DateTime.now().difference(_lastPressedAt!) >
                const Duration(seconds: 2)) {
          _lastPressedAt = DateTime.now();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.grey[700],
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ).copyWith(left: 0),
              closeIconColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              showCloseIcon: true,
              content: Text(
                'اضغط مرة أخرى للخروج من التطبيق',
                style: AppStyle.styleMedium14.copyWith(color: Colors.white),
              ),
              duration: const Duration(milliseconds: 2000),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        }
        return true;
      },
      child: widget.child,
    );
  }
}
