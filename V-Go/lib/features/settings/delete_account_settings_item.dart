import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../../core/helpers/extensions.dart';
import '../../core/theming/app_colors.dart';
import '../../core/theming/app_style.dart';
import '../../core/utils/widgets/custom_toastification.dart';
import '../auth/presentation/logic/cubit/auth_cubit.dart';
import '../auth/presentation/logic/cubit/auth_state_extension.dart';
import 'settings_item.dart';

/// Permanently deletes the signed-in account (required by the App Store and
/// Google Play), then signs out.
class DeleteAccountSettingsItem extends StatelessWidget {
  const DeleteAccountSettingsItem({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          current.status.isLogoutFailure ||
          current.status.isLogoutSuccess ||
          current.status.isLogoutLoading,
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
      child: SettingsItem(
        title: 'حذف الحساب',
        icon: HugeIcons.strokeRoundedDelete02,
        onTap: () {
          AwesomeDialog(
            context: context,
            animType: AnimType.rightSlide,
            dialogType: DialogType.warning,
            title: 'حذف الحساب نهائياً',
            desc: 'حسابك وبياناتك الشخصية هيتحذفوا ومش هتقدر ترجعهم. متأكد؟',
            dialogBackgroundColor: AppColors.darkGrey,
            titleTextStyle: AppStyle.styleMedium16.copyWith(color: AppColors.white),
            descTextStyle: AppStyle.styleRegular14.copyWith(color: AppColors.white),
            btnCancelOnPress: () {},
            btnOkOnPress: () => context.read<AuthCubit>().deleteAccount(),
            btnOkColor: Colors.red,
            buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
            btnOkText: 'احذف حسابي',
            btnCancelText: 'إلغاء',
            reverseBtnOrder: true,
          ).show();
        },
      ),
    );
  }
}
