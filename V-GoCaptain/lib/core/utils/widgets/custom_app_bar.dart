import 'package:flutter/material.dart';

import '../../theming/app_colors.dart';
import '../../theming/app_style.dart';

AppBar customAppBar({
  required String title,
  bool reverseColors = true,
}) {
  return AppBar(
    automaticallyImplyLeading: false,
    foregroundColor: reverseColors ? AppColors.white : AppColors.black,
    backgroundColor: reverseColors ? AppColors.white : AppColors.primary,
    title: Text(title, style: AppStyle.styleMedium18),
    centerTitle: true,
    forceMaterialTransparency: reverseColors ? true : false,
    leadingWidth: 60,
  );
}
