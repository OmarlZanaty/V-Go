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

class DeleteUserButton extends StatelessWidget {
  const DeleteUserButton({required this.userId, super.key});
  final String userId;
  @override
  Widget build(BuildContext context) {
    return BlocListener<UserCubit, UserState>(
      listenWhen: (previous, current) => _buildAndListenWhen(current),
      listener: (context, state) {
        if (state.status.isDeleteUserSuccess) {
          context.pop();

          successToast(context, 'عملية ناجحة', state.successMessage);
          context.pop();
        } else if (state.status.isDeleteUserFailure) {
          context.pop();
          errorToast(context, 'عملية فاشلة', state.errorMessage);
        } else if (state.status.isDeleteUserLoading) {
          loadingDialog(context);
        }
      },
      child: CustomButton(
        onPressed: () {
          _showDeleteDialog(context);
        },
        text: 'حذف',
        textColor: AppColors.white,
        height: 52,
        color: Colors.red,
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    AwesomeDialog(
      context: context,
      animType: AnimType.rightSlide,
      dialogType: DialogType.question,
      title: 'حذف المستخدم',
      desc: 'هل تريد حذف هذا المستخدم؟',
      dialogBackgroundColor: AppColors.darkGrey,
      titleTextStyle: AppStyle.styleMedium16.copyWith(color: AppColors.white),
      descTextStyle: AppStyle.styleRegular14.copyWith(color: AppColors.white),
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        context.read<UserCubit>().deleteUser(userId);
      },
      buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
      btnOkText: 'حذف',
      btnCancelText: 'اغلاق',
      reverseBtnOrder: true,
    ).show();
  }

  bool _buildAndListenWhen(UserState state) {
    return state.status.isDeleteUserLoading ||
        state.status.isDeleteUserSuccess ||
        state.status.isDeleteUserFailure;
  }
}
