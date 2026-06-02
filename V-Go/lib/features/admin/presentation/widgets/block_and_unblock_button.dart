import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';

class BlockButton extends StatelessWidget {
  const BlockButton({required this.userId, required this.isBlocked, super.key});
  final String userId;
  final bool isBlocked;
  @override
  Widget build(BuildContext context) {
    return BlocListener<UserCubit, UserState>(
      listenWhen: (previous, current) => _buildAndListenWhen(current),
      listener: (context, state) {
        if (state.status.isBlockOrUnblockUserSuccess) {
          context.pop();
          successToast(context, 'عملية ناجحة', state.successMessage);
          context.pop();
        } else if (state.status.isBlockOrUnblockUserFailure) {
          context.pop();
          errorToast(context, 'عملية فاشلة', state.errorMessage);
        } else if (state.status.isBlockOrUnblockUserLoading) {
          loadingDialog(context);
        }
      },
      child: CustomButton(
        height: 52,
        text: isBlocked ? 'الغاء الحظر' : 'حظر',
        textColor: isBlocked ? Colors.white : AppColors.black,
        color: isBlocked ? Colors.green : AppColors.primary,
        onPressed: () {
          _showBlockOrUnblockDialog(context, isBlocked);
        },
      ),
    );
  }

  bool _buildAndListenWhen(UserState state) {
    return state.status.isBlockOrUnblockUserLoading ||
        state.status.isBlockOrUnblockUserSuccess ||
        state.status.isBlockOrUnblockUserFailure;
  }

  Future<void> _showBlockOrUnblockDialog(
    BuildContext context,
    bool isBlocked,
  ) async {
    AwesomeDialog(
      context: context,
      animType: AnimType.rightSlide,
      dialogType: DialogType.question,
      title: isBlocked ? 'الغاء الحظر' : 'حظر المستخدم',
      desc: isBlocked
          ? 'هل تريد الغاء حظر هذا المستخدم؟'
          : 'هل تريد حظر هذا المستخدم؟',
      dialogBackgroundColor: AppColors.darkGrey,
      titleTextStyle: AppStyle.styleMedium16.copyWith(color: AppColors.white),
      descTextStyle: AppStyle.styleRegular14.copyWith(color: AppColors.white),
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        context.read<UserCubit>().blockOrUnblockUser(
          userId,
          isBlocked: isBlocked,
        );
      },
      buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
      btnOkText: isBlocked ? 'الغاء الحظر' : 'حظر',
      btnCancelText: 'اغلاق',
      reverseBtnOrder: true,
    ).show();
  }
}
