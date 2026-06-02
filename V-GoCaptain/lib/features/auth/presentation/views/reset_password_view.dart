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

/// Step 1 of password reset: enter email, receive an OTP.
class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('استعادة كلمة المرور',
          style: AppStyle.title.copyWith(color: AppColors.black))),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is ForgotOtpSent) {
            Navigator.of(context).pushNamed(
              Routes.otpViewRoute,
              arguments: {'email': state.email, 'type': 'ResetPassword'},
            );
          } else if (state is AuthError) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              title: Text(state.message, style: AppStyle.body),
              autoCloseDuration: const Duration(seconds: 4),
              alignment: Alignment.bottomCenter,
            );
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
                  Text('أدخل بريدك الإلكتروني وسنرسل لك رمز التحقق',
                      style: AppStyle.hint, textAlign: TextAlign.center),
                  SizedBox(height: 24.h),
                  AuthTextField(
                    controller: _email,
                    hint: 'البريد الإلكتروني',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'بريد غير صالح' : null,
                  ),
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
                                context
                                    .read<AuthCubit>()
                                    .forgetPassword(_email.text.trim());
                              }
                            },
                      child: loading
                          ? const SpinKitThreeBounce(
                              color: AppColors.black, size: 22)
                          : Text('إرسال الرمز', style: AppStyle.button),
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
