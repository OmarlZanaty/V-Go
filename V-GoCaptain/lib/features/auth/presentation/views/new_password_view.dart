import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/cubit/auth_cubit.dart';
import '../widgets/auth_text_field.dart';

/// Final step of password reset: set a new password (OTP already verified).
class NewPasswordView extends StatefulWidget {
  const NewPasswordView({super.key, required this.email});

  final String email;

  @override
  State<NewPasswordView> createState() => _NewPasswordViewState();
}

class _NewPasswordViewState extends State<NewPasswordView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toast(BuildContext context, String msg, {bool error = true}) {
    toastification.show(
      context: context,
      type: error ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: Text(msg, style: AppStyle.body),
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.bottomCenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('كلمة مرور جديدة',
          style: AppStyle.title.copyWith(color: AppColors.black))),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is ResetPasswordSuccess) {
            _toast(context, 'تم تغيير كلمة المرور بنجاح', error: false);
            Navigator.of(context)
                .pushNamedAndRemoveUntil(Routes.loginViewRoute, (r) => false);
          } else if (state is AuthError) {
            _toast(context, state.message);
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 20.h),
                  AuthTextField(controller: _password, hint: 'كلمة المرور الجديدة',
                      icon: Icons.lock_outline, obscure: true,
                      validator: (v) => (v==null||v.length<6) ? '6 أحرف على الأقل' : null),
                  SizedBox(height: 14.h),
                  AuthTextField(controller: _confirm, hint: 'تأكيد كلمة المرور',
                      icon: Icons.lock_outline, obscure: true,
                      validator: (v) => v != _password.text ? 'غير متطابقة' : null),
                  SizedBox(height: 24.h),
                  SizedBox(
                    height: 52.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r)),
                      ),
                      onPressed: loading
                          ? null
                          : () {
                              if (_formKey.currentState?.validate() ?? false) {
                                context.read<AuthCubit>().resetPassword(
                                      email: widget.email,
                                      newPassword: _password.text,
                                    );
                              }
                            },
                      child: loading
                          ? const SpinKitThreeBounce(color: AppColors.black, size: 22)
                          : Text('حفظ', style: AppStyle.button),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
