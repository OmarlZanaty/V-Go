import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/cubit/auth_state_extension.dart';
import 'forget_password_dialog.dart';

class ForgetPasswordSection extends StatefulWidget {
  const ForgetPasswordSection({super.key});

  @override
  State<ForgetPasswordSection> createState() => _ForgetPasswordSectionState();
}

class _ForgetPasswordSectionState extends State<ForgetPasswordSection> {
  final TextEditingController emailController = TextEditingController();
  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) => _listenWhen(current),
      listener: (context, state) {
        if (state.status.isForgotPasswordSuccess) {
          context.pop();
          log('email pass to otp : ${state.email}');
          context.pushNamed(
            Routes.otpViewRoute,
            arguments: {'isForgetPassword': true, 'email': state.email},
          );
          successToast(context, 'عملية ناجحة', state.message);
        } else if (state.status.isForgotPasswordFailure) {
          context.pop();
          errorToast(context, 'حدث خطا', state.errorMessage);
        } else if (state.status.isForgotPasswordLoading) {
          loadingDialog(context);
        }
      },
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () {
            forgetPasswordDialog(context, emailController);
          },
          child: Text(
            'نسيت كلمة المرور؟',
            style: AppStyle.styleRegular14.copyWith(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  bool _listenWhen(AuthState state) {
    return state.status.isForgotPasswordLoading ||
        state.status.isForgotPasswordSuccess ||
        state.status.isForgotPasswordFailure;
  }
}
