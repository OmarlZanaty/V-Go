import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/get_route.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/cubit/auth_state_extension.dart';

class GoogleLoginButton extends StatelessWidget {
  const GoogleLoginButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) => _listenWhen(current),
      listener: (context, state) async {
        if (state.status.isLoginWithGoogleSuccess) {
          context.pop();
          context.pushNamedAndRemoveUntil(
            getRoute(),
            predicate: (route) => false,
          );
        } else if (state.status.isLoginWithGoogleFailure) {
          context.pop();
          errorToast(context, 'حدث خطا', state.errorMessage);
        } else if (state.status.isLoginWithGoogleLoading) {
          loadingDialog(context);
        } else if (state.status.isInitial) {
          context.pop();
        }
      },
      child: ElevatedButton.icon(
        onPressed: () {
          FocusManager.instance.primaryFocus?.unfocus();
          context.read<AuthCubit>().googleLogin();
        },
        label: Text('تسجيل الدخول باستخدام ', style: AppStyle.styleMedium16),
        icon: Image.asset('assets/images/google.png', width: 34),
        style: ElevatedButton.styleFrom(
          iconAlignment: IconAlignment.end,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.white),
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }

  bool _listenWhen(AuthState state) =>
      state.status.isLoginWithGoogleSuccess ||
      state.status.isLoginWithGoogleFailure ||
      state.status.isLoginWithGoogleLoading ||
      state.status.isInitial;
}
