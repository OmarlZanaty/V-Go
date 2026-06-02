import 'package:flutter/material.dart';

import '../../helpers/spacing.dart';
import '../../theming/app_colors.dart';
import '../../theming/app_style.dart';

AppBar customAppBar({
  required String title,
  bool showLogo = false,
  bool reverseColors = true,
}) {
  return AppBar(
    foregroundColor: reverseColors ? AppColors.white : AppColors.black,
    backgroundColor: reverseColors ? AppColors.white : AppColors.primary,
    title: Text(title, style: AppStyle.styleMedium18),
    centerTitle: true,
    forceMaterialTransparency: reverseColors ? true : false,
    leadingWidth: 60,
    actions: showLogo
        ? [
            Image.asset('assets/images/v-go--icon.png', height: 40),
            horizontalSpace(5),
          ]
        : [],
  );
}
