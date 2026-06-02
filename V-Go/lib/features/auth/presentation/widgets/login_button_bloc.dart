import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/app_regex.dart';
import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/get_route.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/cubit/auth_state_extension.dart';

class LoginButtonBloc extends StatelessWidget {
  const LoginButtonBloc({
    required TextEditingController emailController,
    required TextEditingController passwordController,
    super.key,
  }) : _emailController = emailController,
       _passwordController = passwordController;

  final TextEditingController _emailController;
  final TextEditingController _passwordController;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      buildWhen: (previous, current) => _buildAndListenWhen(current),
      listenWhen: (previous, current) => _buildAndListenWhen(current),
      listener: (context, state) {
        if (state.status.isLoginSuccess) {
          context.pushNamedAndRemoveUntil(
            getRoute(),
            predicate: (route) => false,
          );
        }
        if (state.status.isLoginFailure) {
          errorToast(context, 'حدث خطا', state.errorMessage);
        }
      },
      builder: (context, state) {
        return state.status.isLoginLoading
            ? const CustomLoadingWidget()
            : CustomButton(
                text: 'تسجيل الدخول',
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _validateEmailAndPassword(context);
                },
              );
      },
    );
  }

  bool _buildAndListenWhen(AuthState state) {
    return state.status.isLoginLoading ||
        state.status.isLoginFailure ||
        state.status.isLoginSuccess;
  }

  void _validateEmailAndPassword(BuildContext context) {
    if (_emailController.text.isEmpty ||
        !AppRegex.isEmailValid(_emailController.text)) {
      errorToast(context, 'حدث خطا', 'البريد الالكتروني غير صحيح');
      return;
    }
    if (_passwordController.text.isEmpty) {
      errorToast(context, 'حدث خطا', 'كلمه المرور مطلوب');
      return;
    }
    context.read<AuthCubit>().login(
      _emailController.text,
      _passwordController.text,
    );
  }
}
