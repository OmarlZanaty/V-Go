import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/get_route.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../logic/phone_auth_cubit/phone_auth_cubit.dart';

/// Phone OTP login — phone entry switches to the code screen in place so the
/// single [PhoneAuthCubit] (which holds the verification id) is reused.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'تسجيل الدخول بالهاتف'),
      body: BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
        listener: (context, state) {
          switch (state.status) {
            case PhoneAuthStatus.loginSuccess:
              context.pushNamedAndRemoveUntil(
                getRoute(),
                predicate: (route) => false,
              );
            case PhoneAuthStatus.newUser:
              context.pushNamed(
                Routes.phoneSignupViewRoute,
                arguments: state.phone,
              );
            case PhoneAuthStatus.codeSendFailure:
            case PhoneAuthStatus.verifyFailure:
              errorToast(context, 'حدث خطأ', state.errorMessage);
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

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                verticalSpace(24),
                if (!codeSent) ...[
                  Text(
                    'أدخل رقم هاتفك وسنرسل لك رمز التحقق عبر رسالة نصية.',
                    style: AppStyle.styleMedium14,
                  ),
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
                          text: 'إرسال الرمز',
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            final p = _phoneController.text.trim();
                            if (p.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
                              errorToast(
                                context,
                                'تنبيه',
                                'يرجى إدخال رقم هاتف صحيح.',
                              );
                              return;
                            }
                            cubit.sendCode(p);
                          },
                        ),
                ] else ...[
                  Text(
                    'أدخل الرمز المكوّن من 6 أرقام المُرسل إلى ${state.phone}',
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
                          text: 'تأكيد',
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            final code = _otpController.text.trim();
                            if (code.length < 6) {
                              errorToast(
                                context,
                                'تنبيه',
                                'الرمز يجب أن يكون 6 أرقام.',
                              );
                              return;
                            }
                            cubit.verifyCode(code);
                          },
                        ),
                  verticalSpace(12),
                  state.cooldownSeconds > 0
                      ? Text(
                          'إعادة الإرسال بعد ${state.cooldownSeconds} ث',
                          textAlign: TextAlign.center,
                          style: AppStyle.styleMedium14,
                        )
                      : TextButton(
                          onPressed: busy ? null : () => cubit.sendCode(state.phone),
                          child: const Text('إعادة إرسال الرمز'),
                        ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
