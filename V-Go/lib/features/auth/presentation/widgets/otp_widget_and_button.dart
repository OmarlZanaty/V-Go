import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/cubit/auth_state_extension.dart';
import 'otp_widget.dart';

class OtpWidgetAndButton extends StatefulWidget {
  const OtpWidgetAndButton({
    required this.isForgetPassword,
    required this.email,
    super.key,
  });

  final bool isForgetPassword;
  final String email;

  @override
  State<OtpWidgetAndButton> createState() => _OtpWidgetAndButtonState();
}

class _OtpWidgetAndButtonState extends State<OtpWidgetAndButton> {
  String otp = '';
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return Column(
          children: [
            OtpWidget(
              onOtpChanged: (otpWidgetValue) {
                otp = otpWidgetValue;
              },
            ),
            verticalSpace(40),
            BlocConsumer<AuthCubit, AuthState>(
              buildWhen: (previous, current) => _buildAndListenWhen(current),
              listenWhen: (previous, current) => _buildAndListenWhen(current),
              listener: (context, state) {
                if (state.status.isOtpVerificationSuccess) {
                  if (widget.isForgetPassword) {
                    context.pushNamed(
                      Routes.resetPasswordViewRoute,
                      arguments: widget.email,
                    );
                  } else {
                    context.pushNamed(Routes.loginViewRoute);
                    successToast(context, 'عملية ناجحة', state.message);
                  }
                } else if (state.status.isOtpVerificationFailure) {
                  errorToast(context, 'حدث خطا', state.errorMessage);
                }
              },
              builder: (context, state) {
                return state.status.isOtpVerificationLoading
                    ? const CustomLoadingWidget()
                    : SlideInUp(
                        from: 400,
                        child: CustomButton(
                          text: 'تحقق',
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            _otpValidation(state, context);
                          },
                        ),
                      );
              },
            ),
          ],
        );
      },
    );
  }

  void _otpValidation(AuthState state, BuildContext context) {
    if (otp.length == 6) {
      context.read<AuthCubit>().otpVerification(
        otp,
        widget.email,
        widget.isForgetPassword ? 'ResetPassword' : 'Register',
      );
    } else {
      errorToast(context, 'رمز التحقق غير صالح', 'يرجى إدخال رمز تحقق صالح');
    }
  }

  bool _buildAndListenWhen(AuthState state) {
    return state.status.isOtpVerificationLoading ||
        state.status.isOtpVerificationSuccess ||
        state.status.isOtpVerificationFailure;
  }
}
