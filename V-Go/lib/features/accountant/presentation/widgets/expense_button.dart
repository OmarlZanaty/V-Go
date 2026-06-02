import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/statistics_cubit/statistics_cubit.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import 'add_expense_dialog.dart';

class ExpenseButton extends StatefulWidget {
  const ExpenseButton({super.key});

  @override
  State<ExpenseButton> createState() => _ExpenseButtonState();
}

class _ExpenseButtonState extends State<ExpenseButton> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  @override
  void initState() {
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StatisticsCubit, StatisticsState>(
      listenWhen: (previous, current) => _listenWhen(current),
      listener: (context, state) {
        if (state.status.isAddExpenseSuccess) {
          context.pop();
          successToast(context, 'عملية ناجحة', state.successMessage);
        } else if (state.status.isAddExpenseFailure) {
          context.pop();
          errorToast(context, 'عملية فاشلة', state.errorMessage);
        } else if (state.status.isAddExpenseLoading) {
          loadingDialog(context);
        }
      },
      child: ElevatedButton.icon(
        onPressed: () {
          addExpenseDialog(context, _amountController, _descriptionController);
        },
        label: Text('اضافة مصروف جديد', style: AppStyle.styleMedium16),
        icon: const Icon(Icons.add),
        style: ElevatedButton.styleFrom(
          iconSize: 24,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.black,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }

  bool _listenWhen(StatisticsState state) {
    return state.status.isAddExpenseSuccess ||
        state.status.isAddExpenseFailure ||
        state.status.isAddExpenseLoading;
  }
}
