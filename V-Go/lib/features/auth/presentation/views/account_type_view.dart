import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_button.dart';

class AccountTypeView extends StatelessWidget {
  const AccountTypeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideInDown(
              from: 200,
              child: Image.asset('assets/images/v-go-logo.png', width: 0.85.sw),
            ),
            verticalSpace(30),
            SlideInLeft(
              from: 200,
              delay: const Duration(milliseconds: 100),
              child: CustomButton(
                text: 'تسجيل دخول',
                onPressed: () {
                  context.pushNamed(Routes.loginViewRoute);
                },
              ),
            ),
            verticalSpace(14),
            SlideInLeft(
              from: 200,
              delay: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: () {
                  context.pushNamed(Routes.registerViewRoute);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: const RoundedRectangleBorder(
                    side: BorderSide(color: AppColors.primary),
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                ),
                child: Text('انشاء حساب عميل', style: AppStyle.styleMedium16),
              ),
            ),

            verticalSpace(14),
            SlideInLeft(
              from: 200,
              delay: const Duration(milliseconds: 300),
              child: ElevatedButton(
                onPressed: () {
                  context.pushNamed(Routes.addDriverViewRoute);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: const RoundedRectangleBorder(
                    side: BorderSide(color: AppColors.primary),
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                ),
                child: Text('انشاء حساب سائق', style: AppStyle.styleMedium16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
