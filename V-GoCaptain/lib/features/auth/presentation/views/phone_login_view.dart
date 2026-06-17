import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../logic/phone_auth_cubit/phone_auth_cubit.dart';

enum _AuthScreen { phone, password, resetCode, resetNewPassword }

/// Captain sign-in: phone + password (Google kept). Phone -> we check if it's a
/// registered captain (-> password) or new (-> driver sign-up). Forgot-password
/// uses a one-time OTP, in place. Styled to match the client app.
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

  // Which screen is shown. Advances only on "resting" statuses; transient ones
  // (busy / failure / navigation) keep the current screen so a wrong password
  // stays on the password step instead of bouncing back to phone entry.
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
      appBar: customAppBar(title: 'تسجيل الدخول'),
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
                successToast(
                  context,
                  'تم',
                  'تم تعيين كلمة المرور، يمكنك تسجيل الدخول الآن.',
                );
                context.read<PhoneAuthCubit>().reset();
              case PhoneAuthStatus.failure:
                errorToast(context, 'حدث خطأ', state.errorMessage);
              default:
                break;
            }
          },
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(child: _body(context, state)),
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PhoneAuthState state) {
    final cubit = context.read<PhoneAuthCubit>();
    final next = _screenFor(state.status);
    if (next != null) _screen = next;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        verticalSpace(8),
        Image.asset(
          'assets/images/v-go-logo.png',
          height: 100,
          fit: BoxFit.contain,
        ),
        _step(context, state, cubit),
      ],
    );
  }

  Widget _step(
      BuildContext context, PhoneAuthState state, PhoneAuthCubit cubit) {
    switch (_screen) {
      case _AuthScreen.password:
        return _passwordStep(context, state, cubit);
      case _AuthScreen.resetCode:
        return _resetCodeStep(context, state, cubit);
      case _AuthScreen.resetNewPassword:
        return _newPasswordStep(context, state, cubit);
      case _AuthScreen.phone:
        return _phoneStep(context, state, cubit);
    }
  }

  Widget _phoneStep(
      BuildContext context, PhoneAuthState state, PhoneAuthCubit cubit) {
    final busy = state.status == PhoneAuthStatus.checkingPhone ||
        state.status == PhoneAuthStatus.authenticating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        verticalSpace(24),
        Text('أدخل رقم هاتفك للمتابعة.', style: AppStyle.styleMedium14),
        verticalSpace(16),
        CustomTextField(
          labelText: 'رقم الهاتف',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
        ),
        verticalSpace(24),
        busy
            ? const CustomLoadingWidget()
            : CustomButton(
                text: 'التالي',
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final p = _phoneController.text.trim();
                  if (p.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
                    errorToast(context, 'تنبيه', 'يرجى إدخال رقم هاتف صحيح.');
                    return;
                  }
                  cubit.checkPhone(p);
                },
              ),
        verticalSpace(16),
        Row(children: [
          const Expanded(child: Divider(color: AppColors.grey)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('أو', style: AppStyle.styleMedium14),
          ),
          const Expanded(child: Divider(color: AppColors.grey)),
        ]),
        verticalSpace(16),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: busy ? null : () => cubit.googleSignIn(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(50)),
              ),
            ),
            icon: Image.asset('assets/images/google.png', width: 22, height: 22),
            label: Text(
              'تسجيل الدخول بـ Google',
              style: AppStyle.styleMedium16.copyWith(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordStep(
      BuildContext context, PhoneAuthState state, PhoneAuthCubit cubit) {
    final busy = state.status == PhoneAuthStatus.authenticating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        verticalSpace(24),
        Text('رقم الهاتف: ${state.phone}', style: AppStyle.styleMedium14),
        verticalSpace(16),
        CustomTextField(
          labelText: 'كلمة المرور',
          controller: _passwordController,
          obscureText: true,
        ),
        verticalSpace(8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: busy ? null : () => cubit.sendResetCode(state.phone),
            child: const Text('نسيت كلمة المرور؟'),
          ),
        ),
        verticalSpace(8),
        busy
            ? const CustomLoadingWidget()
            : CustomButton(
                text: 'تسجيل الدخول',
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final pw = _passwordController.text;
                  if (pw.isEmpty) {
                    errorToast(context, 'تنبيه', 'يرجى إدخال كلمة المرور.');
                    return;
                  }
                  cubit.login(pw);
                },
              ),
        verticalSpace(12),
        TextButton(
          onPressed: busy ? null : cubit.reset,
          child: const Text('تغيير رقم الهاتف'),
        ),
      ],
    );
  }

  Widget _resetCodeStep(
      BuildContext context, PhoneAuthState state, PhoneAuthCubit cubit) {
    final busy = state.status == PhoneAuthStatus.sendingCode ||
        state.status == PhoneAuthStatus.verifyingCode;
    final codeSent = state.status != PhoneAuthStatus.sendingCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        verticalSpace(24),
        Text(
          'لإعادة تعيين كلمة المرور، أدخل الرمز المُرسل إلى ${state.phone}',
          style: AppStyle.styleMedium14,
        ),
        verticalSpace(16),
        CustomTextField(
          labelText: 'رمز التحقق',
          controller: _otpController,
          keyboardType: TextInputType.number,
        ),
        verticalSpace(24),
        busy
            ? const CustomLoadingWidget()
            : CustomButton(
                text: 'تأكيد الرمز',
                onPressed: codeSent
                    ? () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        final code = _otpController.text.trim();
                        if (code.length < 6) {
                          errorToast(
                              context, 'تنبيه', 'الرمز يجب أن يكون 6 أرقام.');
                          return;
                        }
                        cubit.verifyResetCode(code);
                      }
                    : () {},
              ),
        verticalSpace(12),
        state.cooldownSeconds > 0
            ? Text(
                'إعادة الإرسال بعد ${state.cooldownSeconds} ث',
                textAlign: TextAlign.center,
                style: AppStyle.styleMedium14,
              )
            : TextButton(
                onPressed: busy ? null : () => cubit.sendResetCode(state.phone),
                child: const Text('إعادة إرسال الرمز'),
              ),
        TextButton(
          onPressed: busy ? null : cubit.reset,
          child: const Text('إلغاء'),
        ),
      ],
    );
  }

  Widget _newPasswordStep(
      BuildContext context, PhoneAuthState state, PhoneAuthCubit cubit) {
    final busy = state.status == PhoneAuthStatus.resetting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        verticalSpace(24),
        Text('أدخل كلمة المرور الجديدة.', style: AppStyle.styleMedium14),
        verticalSpace(16),
        CustomTextField(
          labelText: 'كلمة المرور الجديدة',
          controller: _newPasswordController,
          obscureText: true,
        ),
        verticalSpace(24),
        busy
            ? const CustomLoadingWidget()
            : CustomButton(
                text: 'تعيين كلمة المرور',
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final pw = _newPasswordController.text;
                  if (pw.length < 6) {
                    errorToast(context, 'تنبيه',
                        'كلمة المرور يجب ألا تقل عن 6 أحرف.');
                    return;
                  }
                  cubit.submitNewPassword(pw);
                },
              ),
      ],
    );
  }
}
