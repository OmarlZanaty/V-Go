import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

import '../../theming/app_colors.dart';
import 'custom_loading_widget.dart';

loadingDialog(BuildContext context, {Color? dialogBackgroundColor}) {
  return AwesomeDialog(
    context: context,

    animType: AnimType.rightSlide,
    body: const CustomLoadingWidget(),
    dialogType: DialogType.noHeader,
    dialogBorderRadius: const BorderRadius.all(Radius.circular(12)),
    width: 180,
    padding: const EdgeInsets.symmetric(vertical: 20),
    dialogBackgroundColor: dialogBackgroundColor ?? AppColors.darkGrey,
    dismissOnTouchOutside: false,
    dismissOnBackKeyPress: false,
    bodyHeaderDistance: 0,
  ).show();
}
