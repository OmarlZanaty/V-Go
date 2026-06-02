import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../features/auth/presentation/logic/cubit/auth_cubit.dart';
import '../../../features/auth/presentation/logic/cubit/auth_state_extension.dart';
import '../../cache/cache_helper.dart';
import '../../helpers/extensions.dart';
import '../../routing/routes.dart';
import '../../theming/app_colors.dart';
import '../../theming/app_style.dart';
import '../app_constants.dart';
import 'custom_button.dart';
import 'custom_toastification.dart';
import 'loading_dialog.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key, this.isIcon = false});
  final bool isIcon;
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) => _listenWhen(current),
      listener: (context, state) {
        if (state.status.isLogoutSuccess) {
          context.pop();
          context.pushNamedAndRemoveUntil(
            Routes.accountTypeViewRoute,
            predicate: (route) => false,
          );
        } else if (state.status.isLogoutFailure) {
          context.pop();
          errorToast(context, 'حدث خطا', state.errorMessage);
        } else if (state.status.isLogoutLoading) {
          loadingDialog(context);
        }
      },
      child: isIcon
          ? IconButton(
              onPressed: () => _logoutDialog(context),
              icon: const Icon(HugeIcons.strokeRoundedLogin01, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: AppColors.white,
              ),
            )
          : CustomButton(
              text: 'تسجيل الخروج',
              textColor: AppColors.white,
              onPressed: () => _logoutDialog(context),
              color: Colors.red,
              height: 50,
            ),
    );
  }

  bool _listenWhen(AuthState state) =>
      state.status.isLogoutLoading ||
      state.status.isLogoutSuccess ||
      state.status.isLogoutFailure;

  Future<void> _logoutDialog(BuildContext context) async {
    AwesomeDialog(
      context: context,
      animType: AnimType.rightSlide,
      dialogType: DialogType.question,
      title: 'تسجيل الخروج',
      desc: 'هل انت متاكد من تسجيل الخروج ؟',
      dialogBackgroundColor: AppColors.darkGrey,
      titleTextStyle: AppStyle.styleMedium16.copyWith(color: AppColors.white),
      descTextStyle: AppStyle.styleRegular14.copyWith(color: AppColors.white),
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final refreshToken = await CacheHelper.getSecuredString(
          AppConstants.refreshToken,
        );
        if (context.mounted) {
          context.read<AuthCubit>().logout(refreshToken: refreshToken);
        }
      },
      buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
      btnOkText: 'نعم',
      btnCancelText: 'لا',
      reverseBtnOrder: true,
    ).show();
  }
}
