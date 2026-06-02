import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/cubit/auth_state_extension.dart';

class ChangePasswordButton extends StatelessWidget {
  const ChangePasswordButton({
    required this.email,
    required this.newPasswordController,
    required this.oldPasswordController,
    required this.formKey,
    super.key,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController newPasswordController;
  final TextEditingController oldPasswordController;
  final TextEditingController email;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status.isChangePasswordSuccess) {
          successToast(context, 'عملية ناجحة', state.message);
          context.pop();
        } else if (state.status.isChangePasswordFailure) {
          errorToast(context, 'حدث خطا', state.errorMessage);
        }
      },
      builder: (context, state) {
        return state.status.isChangePasswordLoading
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
      context.read<AuthCubit>().changePassword(
        email.text.trim(),
        oldPasswordController.text,
        newPasswordController.text,
      );
    }
  }
}
