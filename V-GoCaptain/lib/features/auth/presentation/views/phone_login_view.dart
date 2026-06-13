import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/phone_auth_cubit/phone_auth_cubit.dart';

enum _AuthScreen { phone, password, resetCode, resetNewPassword }

/// Captain sign-in: phone + password (Google kept). Phone -> we check if it's a
/// registered captain (-> password) or new (-> driver sign-up). Forgot-password
/// uses a one-time OTP, in place.
class PhoneLoginView extends StatefulWidget {
  const PhoneLoginView({super.key});

  @override
  State<PhoneLoginView> createState() => _PhoneLoginViewState();
}

class _PhoneLoginViewState extends State<PhoneLoginView> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  _AuthScreen _screen = _AuthScreen.phone;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
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

  _AuthScreen? _screenFor(PhoneAuthStatus s) {
    switch (s) {
      case PhoneAuthStatus.initial:
        return _AuthScreen.phone;
      case PhoneAuthStatus.existingUser:
        return _AuthScreen.password;
      case PhoneAuthStatus.sendingCode:
      case PhoneAuthStatus.codeSent:
      case PhoneAuthStatus.verifyingCode:
        return _AuthScreen.resetCode;
      case PhoneAuthStatus.codeVerified:
      case PhoneAuthStatus.resetting:
        return _AuthScreen.resetNewPassword;
      default:
        return null; // checkingPhone / authenticating / failure / nav: keep
    }
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
                  arguments: {
                    'phone': state.phone,
                    'cubit': context.read<PhoneAuthCubit>(),
                  },
                );
              case PhoneAuthStatus.resetSuccess:
                _toast('تم تعيين كلمة المرور، يمكنك تسجيل الدخول الآن.',
                    error: false);
                context.read<PhoneAuthCubit>().reset();
              case PhoneAuthStatus.failure:
                _toast(state.errorMessage);
              default:
                break;
            }
          },
          builder: (context, state) {
            final cubit = context.read<PhoneAuthCubit>();
            final next = _screenFor(state.status);
            if (next != null) _screen = next;

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
                  ..._screenChildren(context, state, cubit),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _screenChildren(
      BuildContext context, PhoneAuthState state, PhoneAuthCubit cubit) {
    switch (_screen) {
      case _AuthScreen.password:
        return _passwordChildren(state, cubit);
      case _AuthScreen.resetCode:
        return _resetCodeChildren(state, cubit);
      case _AuthScreen.resetNewPassword:
        return _newPasswordChildren(state, cubit);
      case _AuthScreen.phone:
        return _phoneChildren(state, cubit);
    }
  }

  List<Widget> _phoneChildren(PhoneAuthState state, PhoneAuthCubit cubit) {
    final busy = state.status == PhoneAuthStatus.checkingPhone ||
        state.status == PhoneAuthStatus.authenticating;
    return [
      Text('أدخل رقم هاتفك للمتابعة.',
          style: AppStyle.hint, textAlign: TextAlign.center),
      SizedBox(height: 16.h),
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: AppStyle.body,
        decoration: _decoration('رقم الهاتف', Icons.phone_outlined),
      ),
      SizedBox(height: 24.h),
      _button('التالي', busy, () {
        final p = _phoneController.text.trim();
        if (p.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
          _toast('يرجى إدخال رقم هاتف صحيح.');
          return;
        }
        cubit.checkPhone(p);
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
                      strokeWidth: 2, color: AppColors.primary),
                )
              : Image.asset('assets/images/google.png',
                  width: 22.w, height: 22.h),
          label: Text('تسجيل الدخول بـ Google',
              style: AppStyle.body.copyWith(color: AppColors.primary)),
        ),
      ),
    ];
  }

  List<Widget> _passwordChildren(PhoneAuthState state, PhoneAuthCubit cubit) {
    final busy = state.status == PhoneAuthStatus.authenticating;
    return [
      Text('رقم الهاتف: ${state.phone}', style: AppStyle.hint),
      SizedBox(height: 16.h),
      TextField(
        controller: _passwordController,
        obscureText: true,
        style: AppStyle.body,
        decoration: _decoration('كلمة المرور', Icons.lock_outline),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: busy ? null : () => cubit.sendResetCode(state.phone),
          child: Text('نسيت كلمة المرور؟',
              style: AppStyle.body.copyWith(color: AppColors.primary)),
        ),
      ),
      SizedBox(height: 8.h),
      _button('تسجيل الدخول', busy, () {
        final pw = _passwordController.text;
        if (pw.isEmpty) {
          _toast('يرجى إدخال كلمة المرور.');
          return;
        }
        cubit.login(pw);
      }),
      SizedBox(height: 8.h),
      TextButton(
        onPressed: busy ? null : cubit.reset,
        child: Text('تغيير رقم الهاتف',
            style: AppStyle.body.copyWith(color: AppColors.primary)),
      ),
    ];
  }

  List<Widget> _resetCodeChildren(PhoneAuthState state, PhoneAuthCubit cubit) {
    final busy = state.status == PhoneAuthStatus.sendingCode ||
        state.status == PhoneAuthStatus.verifyingCode;
    final codeSent = state.status != PhoneAuthStatus.sendingCode;
    return [
      Text('أدخل الرمز المُرسل إلى ${state.phone} لإعادة تعيين كلمة المرور',
          style: AppStyle.hint, textAlign: TextAlign.center),
      SizedBox(height: 16.h),
      TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        style: AppStyle.body,
        decoration: _decoration('رمز التحقق', Icons.sms_outlined),
      ),
      SizedBox(height: 24.h),
      _button('تأكيد الرمز', busy, () {
        if (!codeSent) return;
        final c = _otpController.text.trim();
        if (c.length < 6) {
          _toast('الرمز يجب أن يكون 6 أرقام.');
          return;
        }
        cubit.verifyResetCode(c);
      }),
      SizedBox(height: 8.h),
      state.cooldownSeconds > 0
          ? Text('إعادة الإرسال بعد ${state.cooldownSeconds} ث',
              textAlign: TextAlign.center, style: AppStyle.hint)
          : TextButton(
              onPressed: busy ? null : () => cubit.sendResetCode(state.phone),
              child: Text('إعادة إرسال الرمز',
                  style: AppStyle.body.copyWith(color: AppColors.primary)),
            ),
      TextButton(
        onPressed: busy ? null : cubit.reset,
        child: Text('إلغاء',
            style: AppStyle.body.copyWith(color: AppColors.primary)),
      ),
    ];
  }

  List<Widget> _newPasswordChildren(PhoneAuthState state, PhoneAuthCubit cubit) {
    final busy = state.status == PhoneAuthStatus.resetting;
    return [
      Text('أدخل كلمة المرور الجديدة.', style: AppStyle.hint),
      SizedBox(height: 16.h),
      TextField(
        controller: _newPasswordController,
        obscureText: true,
        style: AppStyle.body,
        decoration: _decoration('كلمة المرور الجديدة', Icons.lock_outline),
      ),
      SizedBox(height: 24.h),
      _button('تعيين كلمة المرور', busy, () {
        final pw = _newPasswordController.text;
        if (pw.length < 6) {
          _toast('كلمة المرور يجب ألا تقل عن 6 أحرف.');
          return;
        }
        cubit.submitNewPassword(pw);
      }),
    ];
  }

  Widget _button(String text, bool busy, VoidCallback onTap) {
    return SizedBox(
      height: 52.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
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
