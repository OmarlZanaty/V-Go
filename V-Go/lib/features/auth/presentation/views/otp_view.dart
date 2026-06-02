import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../widgets/otp_widget_and_button.dart';
import '../widgets/resend_otp_section.dart';

class OtpView extends StatelessWidget {
  const OtpView({
    required this.isForgetPassword,
    required this.email,
    super.key,
  });
  final bool isForgetPassword;
  final String email;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'التحقق من الهوية'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Image.asset('assets/images/v-go-logo-2.png', width: 0.85.sw),
                  Text(
                    "أدخل رمز التحقق الذي ارسل الي بريدك الإلكتروني",
                    style: AppStyle.styleMedium14.copyWith(
                      color: AppColors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  verticalSpace(30),
                  OtpWidgetAndButton(
                    isForgetPassword: isForgetPassword,
                    email: email,
                  ),
                  verticalSpace(20),
                  SlideInLeft(
                    from: 400,
                    delay: const Duration(milliseconds: 250),
                    child: Row(
                      children: [
                        Text(
                          "لم يصلك الرمز؟",
                          style: AppStyle.styleRegular12.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        horizontalSpace(5),
                        ResendOtpSection(
                          isForgetPassword: isForgetPassword,
                          email: email,
                        ),
                      ],
                    ),
                  ),
                  verticalSpace(20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
