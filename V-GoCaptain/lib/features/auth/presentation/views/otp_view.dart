import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/cubit/auth_cubit.dart';

/// Generic OTP screen. Expects route args: { email, type } where type is
/// "Register" or "ResetPassword".
class OtpView extends StatefulWidget {
  const OtpView({super.key, required this.email, required this.type});

  final String email;
  final String type;

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  final _otp = TextEditingController();

  @override
  void dispose() {
    _otp.dispose();
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
      appBar: AppBar(title: Text('رمز التحقق',
          style: AppStyle.title.copyWith(color: AppColors.black))),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is OtpVerified) {
            if (state.type == 'Register') {
              _toast(context, 'تم تأكيد حسابك، سجّل الدخول الآن', error: false);
              Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.loginViewRoute, (r) => false);
            } else {
              Navigator.of(context).pushNamed(
                Routes.newPasswordViewRoute,
                arguments: {'email': widget.email},
              );
            }
          } else if (state is OtpResent) {
            _toast(context, 'تم إرسال الرمز مرة أخرى', error: false);
          } else if (state is AuthError) {
            _toast(context, state.message);
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 20.h),
                Text('أدخل الرمز المرسل إلى', style: AppStyle.hint,
                    textAlign: TextAlign.center),
                SizedBox(height: 4.h),
                Text(widget.email, style: AppStyle.body,
                    textAlign: TextAlign.center),
                SizedBox(height: 28.h),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: AppStyle.heading,
                  decoration: InputDecoration(
                    hintText: '----',
                    hintStyle: AppStyle.hint,
                    filled: true,
                    fillColor: AppColors.darkGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
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
                            if (_otp.text.trim().isEmpty) {
                              _toast(context, 'أدخل رمز التحقق');
                              return;
                            }
                            context.read<AuthCubit>().verifyOtp(
                                  email: widget.email,
                                  otp: _otp.text.trim(),
                                  type: widget.type,
                                );
                          },
                    child: loading
                        ? const SpinKitThreeBounce(color: AppColors.black, size: 22)
                        : Text('تأكيد', style: AppStyle.button),
                  ),
                ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: () => context
                      .read<AuthCubit>()
                      .resendOtp(email: widget.email, type: widget.type),
                  child: Text('إعادة إرسال الرمز',
                      style: AppStyle.hint.copyWith(color: AppColors.primary)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
