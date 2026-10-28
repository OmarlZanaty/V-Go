import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../helpers/navigation_handler.dart';
import '../theming/app_colors.dart';
import '../theming/app_style.dart';

class InAppNotificationBanner {
  static bool show({required String title, required String body}) {
    try {
      final overlay = NavigationHandler.navigatorKey.currentState?.overlay;
      if (overlay == null) return false;

      toastification.show(
        overlayState: overlay,
        alignment: Alignment.topCenter,
        type: ToastificationType.info,
        style: ToastificationStyle.fillColored,
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppStyle.styleMedium14.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        description: Text(
          body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppStyle.styleRegular14.copyWith(color: AppColors.white),
        ),
        icon: const Icon(Icons.notifications),
        animationDuration: const Duration(milliseconds: 600),
        autoCloseDuration: const Duration(seconds: 5),
        foregroundColor: AppColors.white,
        showProgressBar: false,
        closeOnClick: true,
        dragToClose: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
