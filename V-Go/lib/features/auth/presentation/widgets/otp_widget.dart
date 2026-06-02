import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

class OtpWidget extends StatelessWidget {
  final Function(String) onOtpChanged;

  const OtpWidget({required this.onOtpChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: OtpTextField(
        numberOfFields: 6,
        enabledBorderColor: AppColors.lightGrey,
        cursorColor: AppColors.primary,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        fieldWidth: MediaQuery.sizeOf(context).width / 8,
        showFieldAsBox: true,
        textStyle: AppStyle.styleBold24,
        focusedBorderColor: AppColors.primary,
        onSubmit: onOtpChanged,
      ),
    );
  }
}
