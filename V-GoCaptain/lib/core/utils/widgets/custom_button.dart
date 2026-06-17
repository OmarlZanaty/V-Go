import 'package:flutter/material.dart';

import '../../theming/app_colors.dart';
import '../../theming/app_style.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    required this.text,
    required this.onPressed,
    super.key,
    this.color,
    this.width,
    this.height,
    this.textColor,
  });
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final double? width;
  final double? height;
  final Color? textColor;
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: _buttonStyle(),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: AppStyle.styleMedium16.copyWith(
            color: textColor ?? AppColors.black,
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: color ?? AppColors.primary,
      foregroundColor: textColor ?? Colors.black,
      minimumSize: Size(width ?? double.infinity, height ?? 54),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(50)),
      ),
    );
  }
}
