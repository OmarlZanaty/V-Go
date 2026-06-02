import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../logic/cubit/auth_cubit.dart';

forgetPasswordDialog(
  BuildContext context,
  TextEditingController emailController,
) {
  return AwesomeDialog(
    context: context,
    animType: AnimType.rightSlide,
    dialogBackgroundColor: AppColors.darkGrey,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    body: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CustomTextField(
        labelText: 'البريد الإلكتروني',
        controller: emailController,
      ),
    ),
    dialogBorderRadius: const BorderRadius.all(Radius.circular(14)),
    dialogType: DialogType.noHeader,
    btnCancelText: 'إلغاء',
    btnOkText: 'التالي',
    buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
    btnOkOnPress: () {
      if (!emailController.text.trim().isNullOrEmpty()) {
        context.read<AuthCubit>().forgetPassword(emailController.text.trim());
        emailController.clear();
      }
    },
    btnCancelOnPress: () {
      emailController.clear();
    },
    reverseBtnOrder: true,
  ).show();
}
