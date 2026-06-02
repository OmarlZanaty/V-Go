import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/statistics_cubit/statistics_cubit.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../data/model/add_expense_request_model.dart';

addExpenseDialog(
  BuildContext context,
  TextEditingController amountController,
  TextEditingController descriptionController,
) {
  return AwesomeDialog(
    context: context,
    animType: AnimType.rightSlide,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    dialogType: DialogType.noHeader,
    dialogBackgroundColor: AppColors.darkGrey,
    body: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          CustomTextField(
            labelText: 'المبلغ',
            controller: amountController,
            keyboardType: TextInputType.number,
          ),
          verticalSpace(10),
          CustomTextField(
            labelText: 'وصف المصروف',
            controller: descriptionController,
          ),
        ],
      ),
    ),
    dialogBorderRadius: const BorderRadius.all(Radius.circular(14)),
    btnCancelText: 'إلغاء',
    btnOkText: 'اضافة',
    reverseBtnOrder: true,
    buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
    btnOkOnPress: () {
      if (!amountController.text.trim().isNullOrEmpty() &&
          !descriptionController.text.trim().isNullOrEmpty()) {
        final expenseModel = AddExpenseRequestModel(
          cost: double.parse(amountController.text.trim()),
          description: descriptionController.text.trim(),
        );
        context.read<StatisticsCubit>().addExpense(model: expenseModel);
        amountController.clear();
        descriptionController.clear();
      } else {
        errorToast(context, 'حدث خطا', 'يرجي ملء جميع الحقول');
      }
    },
    btnCancelOnPress: () {
      amountController.clear();
      descriptionController.clear();
    },
  ).show();
}
