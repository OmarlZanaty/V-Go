import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/convert_time.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/statistics_cubit/statistics_cubit.dart';
import '../../data/model/all_expenses_response_model.dart';

class ExpenseItem extends StatelessWidget {
  const ExpenseItem({required this.expenseItem, super.key});
  final ExpenseItemModel expenseItem;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () {
          _showDeleteExpenseDialog(context);
        },
        
        horizontalTitleGap: 14,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          radius: 18,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedDelete01,
            color: AppColors.white,
            size: 20,
          ),
        ),
        title: Text(
          expenseItem.description,
          style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
        ),
        subtitle: Align(
          alignment: AlignmentGeometry.centerRight,
          child: Text(
            convertDate(expenseItem.date, includeTime: true),
            style: AppStyle.styleRegular14.copyWith(color: AppColors.white),
            textDirection: TextDirection.ltr,
            
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              expenseItem.cost.toStringAsFixed(2),
              style: AppStyle.styleBold20.copyWith(color: AppColors.primary),
            ),
            horizontalSpace(5),
            Text(
              'ج.م',
              style: AppStyle.styleRegular12.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteExpenseDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      title: 'حذف المصروف',
      desc: 'هل انت متأكد من حذف هذا المصروف؟',
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        context.read<StatisticsCubit>().deleteExpense(
          expenseId: expenseItem.id,
          cost: expenseItem.cost,
        );
      },
      dialogBackgroundColor: AppColors.darkGrey,
      titleTextStyle: AppStyle.styleMedium16.copyWith(color: AppColors.white),
      descTextStyle: AppStyle.styleRegular14.copyWith(color: AppColors.white),
      buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
      reverseBtnOrder: true,
      btnOkText: 'حذف',
      btnCancelText: 'إلغاء',
    ).show();
  }
}
