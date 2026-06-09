import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../logic/cubit/auth_cubit.dart';

class AccountTypeView extends StatelessWidget {
  const AccountTypeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.loginWithGoogleSuccess) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRouter.initialRoute(),
              (_) => false,
            );
          } else if (state.status == AuthStatus.loginWithGoogleNewUser) {
            Navigator.of(context).pushNamed(
              Routes.googleCompleteProfileViewRoute,
              arguments: {
                'idToken': state.googleIdToken,
                'name': state.googleName,
                'photo': state.googlePhoto,
              },
            );
          } else if (state.status == AuthStatus.loginWithGoogleFailure) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              title: Text(state.errorMessage.isNotEmpty ? state.errorMessage : 'فشل تسجيل الدخول بـ Google',
                  style: AppStyle.styleRegular16),
              autoCloseDuration: const Duration(seconds: 4),
              alignment: Alignment.bottomCenter,
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SlideInDown(
                from: 200,
                child:
                    Image.asset('assets/images/v-go-logo.png', width: 0.85.sw),
              ),
              verticalSpace(30),
              SlideInLeft(
                from: 200,
                delay: const Duration(milliseconds: 100),
                child: CustomButton(
                  text: 'تسجيل الدخول / إنشاء حساب',
                  onPressed: () {
                    context.pushNamed(Routes.phoneLoginViewRoute);
                  },
                ),
              ),
              verticalSpace(12),
              SlideInLeft(
                from: 200,
                delay: const Duration(milliseconds: 200),
                child: BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    final loading =
                        state.status == AuthStatus.loginWithGoogleLoading;
                    return SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () =>
                                context.read<AuthCubit>().googleLogin(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        icon: loading
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
                          style: AppStyle.styleRegular16
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
