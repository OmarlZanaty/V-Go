import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';

class CustomSearchField extends StatelessWidget {
  const CustomSearchField({super.key, this.controller, this.focusNode});
  final TextEditingController? controller;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      cursorColor: AppColors.primary,
      style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ابحث هنا...',
        hintStyle: AppStyle.styleMedium14.copyWith(color: Colors.grey),
        prefixIcon: const HugeIcon(
          icon: HugeIcons.strokeRoundedSearch01,
          color: AppColors.primary,
        ),
        border: _border(),
        focusedBorder: _border(color: AppColors.primary),
        enabledBorder: _border(),
      ),
      onChanged: context.read<UserCubit>().searchUsers,
    );
  }

  OutlineInputBorder _border({Color? color}) {
    return OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(
        color: color ?? AppColors.grey.withValues(alpha: 0.5),
      ),
    );
  }
}
