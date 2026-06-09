import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/phone_auth_cubit/phone_auth_cubit.dart';

class PhoneLoginView extends StatefulWidget {
  const PhoneLoginView({super.key});

  @override
  State<PhoneLoginView> createState() => _PhoneLoginViewState();
}

class _PhoneLoginViewState extends State<PhoneLoginView> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = true}) {
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('تسجيل الدخول'),
      ),
      body: SafeArea(
        child: BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
          listener: (context, state) {
            switch (state.status) {
              case PhoneAuthStatus.loginSuccess:
                Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.captainHomeViewRoute,
                  (route) => false,
                );
              case PhoneAuthStatus.newUser:
                Navigator.of(context).pushNamed(
                  Routes.phoneDriverSignupViewRoute,
                  arguments: {'phone': state.phone},
                );
              case PhoneAuthStatus.codeSendFailure:
              case PhoneAuthStatus.verifyFailure:
                _toast(state.errorMessage);
              default:
                break;
            }
          },
          builder: (context, state) {
            final cubit = context.read<PhoneAuthCubit>();
            final codeSent = state.status == PhoneAuthStatus.codeSent ||
                state.status == PhoneAuthStatus.verifying ||
                state.status == PhoneAuthStatus.verifyFailure;
            final busy = state.status == PhoneAuthStatus.sendingCode ||
                state.status == PhoneAuthStatus.verifying;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/v-go-logo.png',
                    height: 100.h,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 24.h),
                  if (!codeSent) ...[
                    Text(
                      'أدخل رقم هاتفك لاستلام رمز التحقق.',
                      style: AppStyle.hint,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: AppStyle.body,
                      decoration: _decoration('رقم الهاتف', Icons.phone_outlined),
                    ),
                    SizedBox(height: 24.h),
                    _button('إرسال الرمز', busy, () {
                      final p = _phoneController.text.trim();
                      if (p.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
                        _toast('يرجى إدخال رقم هاتف صحيح.');
                        return;
                      }
                      cubit.sendCode(p);
                    }),
                    SizedBox(height: 12.h),
                    Row(children: [
                      Expanded(child: Divider(color: AppColors.grey)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Text('أو', style: AppStyle.hint),
                      ),
                      Expanded(child: Divider(color: AppColors.grey)),
                    ]),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => cubit.googleSignIn(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        icon: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              )
                            : Image.asset(
                                'assets/images/google.png',
                                width: 22.w,
                                height: 22.h,
                              ),
                        label: Text(
                          'تسجيل الدخول بـ Google',
                          style: AppStyle.body
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'أدخل الرمز المكوّن من 6 أرقام المُرسل إلى ${state.phone}',
                      style: AppStyle.hint,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: AppStyle.body,
                      decoration: _decoration('رمز التحقق', Icons.sms_outlined),
                    ),
                    SizedBox(height: 24.h),
                    _button('تأكيد', busy, () {
                      final c = _otpController.text.trim();
                      if (c.length < 6) {
                        _toast('الرمز يجب أن يكون 6 أرقام.');
                        return;
                      }
                      cubit.verifyCode(c);
                    }),
                    SizedBox(height: 8.h),
                    state.cooldownSeconds > 0
                        ? Text(
                            'إعادة الإرسال بعد ${state.cooldownSeconds} ث',
                            textAlign: TextAlign.center,
                            style: AppStyle.hint,
                          )
                        : TextButton(
                            onPressed: busy ? null : () => cubit.sendCode(state.phone),
                            child: Text(
                              'إعادة إرسال الرمز',
                              style: AppStyle.body.copyWith(color: AppColors.primary),
                            ),
                          ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _button(String text, bool busy, VoidCallback onTap) {
    return SizedBox(
      height: 52.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        ),
        onPressed: busy
            ? null
            : () {
                FocusManager.instance.primaryFocus?.unfocus();
                onTap();
              },
        child: busy
            ? const SpinKitThreeBounce(color: AppColors.black, size: 22)
            : Text(text, style: AppStyle.button),
      ),
    );
  }

  InputDecoration _decoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppStyle.hint,
      prefixIcon: Icon(icon, color: AppColors.grey),
      filled: true,
      fillColor: AppColors.darkGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide.none,
      ),
    );
  }
}
