import 'package:flutter/material.dart';

import '../../theming/app_colors.dart';

class ObscureIcon extends StatelessWidget {
  const ObscureIcon({
    required this.isObscure,
    required this.onPressed,
    super.key,
    this.labelColor,
  });

  final bool isObscure;
  final Color? labelColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: labelColor ?? AppColors.primary,
      ),
      onPressed: onPressed,
    );
  }
}
