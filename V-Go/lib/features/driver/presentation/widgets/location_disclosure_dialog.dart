import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

class LocationDisclosureDialog {
  static void show({
    required BuildContext context,
    required VoidCallback onAgree,
    required VoidCallback onDeny,
  }) {
    AwesomeDialog(
      context: context,
      dialogBackgroundColor: Colors.white,
      animType: AnimType.bottomSlide,
      title: 'Location Access for Trip Distribution',
      desc:
          'V-go collects location data to enable nearby ride request distribution, real-time navigation, and accurate trip tracking, even when the app is closed or not in use.\n\nThis information is essential for connecting you with riders in your area and ensuring safety throughout the journey.',
      titleTextStyle: AppStyle.styleBold20.copyWith(color: Colors.black),
      descTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.black87),
      btnOkText: 'Agree & Proceed',
      btnCancelText: 'Not Now',
      btnOkColor: AppColors.primary,
      btnCancelColor: Colors.grey,
      dismissOnBackKeyPress: false,
      dismissOnTouchOutside: false,
      btnOkOnPress: onAgree,
      btnCancelOnPress: onDeny,
      buttonsTextStyle: AppStyle.styleMedium14.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ).show();
  }
}
