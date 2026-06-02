import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/statistics_cubit/statistics_cubit.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../../data/model/all_expenses_response_model.dart';
import 'expense_item.dart';

class AllExpensesSection extends StatelessWidget {
  const AllExpensesSection({required this.allExpenses, super.key});
  final AllExpensesResponseModel allExpenses;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'جميع المصروفات',
          style: AppStyle.styleMedium16.copyWith(color: Colors.white),
        ),
        verticalSpace(10),
        Expanded(
          child: BlocListener<StatisticsCubit, StatisticsState>(
            listenWhen: (previous, current) => _listenWhen(current),
            listener: (context, state) {
              if (state.status.isDeleteExpenseSuccess) {
                context.pop();
                successToast(context, 'عملية ناجحة', state.successMessage);
              } else if (state.status.isDeleteExpenseFailure) {
                context.pop();
                errorToast(context, 'عملية فاشلة', state.errorMessage);
              } else if (state.status.isDeleteExpenseLoading) {
                loadingDialog(context);
              }
            },
            child: ListView.builder(
              itemCount: allExpenses.expenses.length,
              padding: const EdgeInsets.only(bottom: 10, top: 5),
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ExpenseItem(expenseItem: allExpenses.expenses[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  bool _listenWhen(StatisticsState current) {
    return current.status.isDeleteExpenseSuccess ||
        current.status.isDeleteExpenseFailure ||
        current.status.isDeleteExpenseLoading;
  }
}
