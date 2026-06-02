import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/statistics_cubit/statistics_cubit.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../widgets/all_expenses_section.dart';
import '../widgets/expense_button.dart';

class ExpenseView extends StatelessWidget {
  const ExpenseView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'المصروفات'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BlocBuilder<StatisticsCubit, StatisticsState>(
          buildWhen: (previous, current) => _buildWhen(current),
          builder: (context, state) {
            if (state.status.isGetAllExpensesSuccess) {
              return Column(
                children: [
                  verticalSpace(10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightWhite,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'اجمالي المصروفات',
                          style: AppStyle.styleMedium18.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        verticalSpace(16),

                        Text(
                          state.allExpensesResponse?.totalExpenses
                                  .toStringAsFixed(2) ??
                              '0.00',
                          style: AppStyle.styleBold38.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        Text('ج.م', style: AppStyle.styleRegular16),
                      ],
                    ),
                  ),
                  verticalSpace(16),
                  const ExpenseButton(),
                  const Divider(
                    color: AppColors.lightWhite,
                    height: 40,
                    indent: 50,
                    endIndent: 50,
                  ),
                  Expanded(
                    child: AllExpensesSection(
                      allExpenses: state.allExpensesResponse!,
                    ),
                  ),
                ],
              );
            } else if (state.status.isGetAllExpensesFailure) {
              return CustomFailureWidget(text: state.errorMessage);
            }
            return const CustomLoadingWidget();
          },
        ),
      ),
    );
  }

  bool _buildWhen(StatisticsState state) {
    return state.status.isGetAllExpensesSuccess ||
        state.status.isGetAllExpensesFailure ||
        state.status.isGetAllExpensesLoading;
  }
}
