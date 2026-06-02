import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/cubit/auth_state_extension.dart';

class ResendOtpSection extends StatelessWidget {
  const ResendOtpSection({
    required this.isForgetPassword,
    required this.email,
    super.key,
  });

  final bool isForgetPassword;
  final String email;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) => _listenWhen(current),
      listener: (context, state) {
        if (state.status.isResendOtpSuccess) {
          context.pop();
          successToast(context, 'عملية ناجحة', state.message);
        } else if (state.status.isResendOtpFailure) {
          context.pop();
          errorToast(context, 'حدث خطا', state.errorMessage);
        } else if (state.status.isResendOtpLoading) {
          loadingDialog(context);
        }
      },
      child: GestureDetector(
        onTap: () {
          context.read<AuthCubit>().resendOtp(
            isForgetPassword ? 'ResetPassword' : 'Register',
            email,
          );
        },
        child: Text(
          'إعادة إرسال رمز التحقق',
          style: AppStyle.styleRegular12.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  bool _listenWhen(AuthState state) {
    return state.status.isResendOtpLoading ||
        state.status.isResendOtpSuccess ||
        state.status.isResendOtpFailure;
  }
}
