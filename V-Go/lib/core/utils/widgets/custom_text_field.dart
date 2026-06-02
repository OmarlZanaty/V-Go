import 'package:flutter/material.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import 'obscure_icon.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    required this.labelText,
    required this.controller,
    super.key,
    this.keyboardType,
    this.obscureText = false,
    this.labelColor,
    this.labelBehavior = false,
    this.onChange,
    this.validator,
  });

  final String labelText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextEditingController controller;
  final Color? labelColor;
  final bool? labelBehavior;
  final void Function(String)? onChange;
  final String? Function(String?)? validator;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isObscure = true;

  @override
  void initState() {
    super.initState();
    _isObscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      cursorColor: widget.labelColor ?? AppColors.primary,
      cursorRadius: const Radius.circular(10),
      obscureText: _isObscure,

      controller: widget.controller,
      keyboardType: widget.keyboardType,
      style: AppStyle.styleMedium16.copyWith(
        color: widget.labelColor ?? AppColors.white,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: widget.validator,
      onChanged: widget.onChange,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.lightWhite,
        labelStyle: AppStyle.styleRegular14.copyWith(
          color: widget.labelColor ?? AppColors.white,
        ),
        suffixIcon: widget.obscureText
            ? ObscureIcon(
                isObscure: _isObscure,
                labelColor: widget.labelColor,
                onPressed: () {
                  setState(() => _isObscure = !_isObscure);
                },
              )
            : null,
        border: _buildBorder(),
        enabledBorder: _buildBorder(),
        focusedErrorBorder: _buildBorder(),
        focusedBorder: _buildBorder(
          color: widget.labelColor ?? AppColors.primary,
        ),
        errorBorder: _buildBorder(color: Colors.red),
        label: Text(
          widget.labelText,
          style: AppStyle.styleRegular14.copyWith(color: widget.labelColor),
        ),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        floatingLabelBehavior: widget.labelBehavior == true
            ? FloatingLabelBehavior.never
            : FloatingLabelBehavior.auto,
      ),
    );
  }

  _buildBorder({Color? color}) {
    return OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: color ?? Colors.transparent, width: 0.75),
    );
  }
}
