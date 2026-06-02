import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/cubit/auth_cubit.dart';
import '../widgets/auth_text_field.dart';

/// Change password for a logged-in captain (requires the old password).
class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _email = TextEditingController();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _old.dispose();
    _new.dispose();
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
      appBar: AppBar(title: Text('تغيير كلمة المرور',
          style: AppStyle.title.copyWith(color: AppColors.black))),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is ChangePasswordSuccess) {
            _toast(context, 'تم تغيير كلمة المرور بنجاح', error: false);
            Navigator.of(context).pop();
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
                  SizedBox(height: 16.h),
                  AuthTextField(controller: _email, hint: 'البريد الإلكتروني',
                      icon: Icons.email_outlined, keyboard: TextInputType.emailAddress,
                      validator: (v) => (v==null||!v.contains('@')) ? 'بريد غير صالح' : null),
                  SizedBox(height: 14.h),
                  AuthTextField(controller: _old, hint: 'كلمة المرور الحالية',
                      icon: Icons.lock_outline, obscure: true,
                      validator: (v) => (v==null||v.isEmpty) ? 'أدخل كلمة المرور الحالية' : null),
                  SizedBox(height: 14.h),
                  AuthTextField(controller: _new, hint: 'كلمة المرور الجديدة',
                      icon: Icons.lock_reset_outlined, obscure: true,
                      validator: (v) => (v==null||v.length<6) ? '6 أحرف على الأقل' : null),
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
                                context.read<AuthCubit>().changePassword(
                                      email: _email.text.trim(),
                                      oldPassword: _old.text,
                                      newPassword: _new.text,
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
