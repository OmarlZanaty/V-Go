import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/cubit/auth_state_extension.dart';

class ResetPasswordButtonBloc extends StatelessWidget {
  const ResetPasswordButtonBloc({
    required this.email,
    required this.newPasswordController,
    required this.confirmNewPasswordController,
    required this.formKey,
    super.key,
  });

  final TextEditingController newPasswordController;
  final TextEditingController confirmNewPasswordController;
  final GlobalKey<FormState> formKey;
  final String email;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status.isResetPasswordSuccess) {
          successToast(context, 'عملية ناجحة', state.message);
          context.pushReplacementNamed(Routes.loginViewRoute);
        } else if (state.status.isResetPasswordFailure) {
          errorToast(context, 'حدث خطا', state.errorMessage);
        }
      },
      builder: (context, state) {
        return state.status.isResetPasswordLoading
            ? const CustomLoadingWidget()
            : CustomButton(
                text: 'تغيير كلمة المرور',
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _validateNewPassword(context);
                },
              );
      },
    );
  }

  void _validateNewPassword(BuildContext context) {
    if (formKey.currentState!.validate()) {
      context.read<AuthCubit>().resetPassword(
        newPasswordController.text,
        email,
      );
    }
  }
}
