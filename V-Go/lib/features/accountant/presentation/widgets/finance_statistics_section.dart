import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/statistics_cubit/statistics_cubit.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../admin/presentation/widgets/dashboard_container.dart';

class FinanceStatisticsSection extends StatefulWidget {
  const FinanceStatisticsSection({super.key});

  @override
  State<FinanceStatisticsSection> createState() =>
      _FinanceStatisticsSectionState();
}

class _FinanceStatisticsSectionState extends State<FinanceStatisticsSection> {
  String _selectedPeriod = 'اليوم';
  void _onPeriodSelected(String period) {
    setState(() => _selectedPeriod = period);
    context.read<StatisticsCubit>().getPeriodData(period);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      buildWhen: (previous, current) => _buildWhen(current),
      builder: (context, state) {
        if (state.status.isGetStatisticsSuccess) {
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedPeriod,
                    style: AppStyle.styleMedium16.copyWith(color: Colors.white),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: _onPeriodSelected,
                    elevation: 2,
                    color: AppColors.darkGrey,
                    itemBuilder: (BuildContext context) => periodOptions
                        .map(
                          (period) => PopupMenuItem<String>(
                            value: period,
                            child: Text(
                              period,
                              style: AppStyle.styleRegular14.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DashboardContainer(
                      title: 'ايرادات',
                      value: state.currentPeriodData!.revenue.toStringAsFixed(
                        2,
                      ),
                    ),
                  ),
                  horizontalSpace(8),
                  Expanded(
                    child: DashboardContainer(
                      title: 'مصروفات',
                      value: state.currentPeriodData!.expenses.toStringAsFixed(
                        2,
                      ),
                      onTap: () => context.pushNamed(Routes.expenseViewRoute),
                    ),
                  ),
                ],
              ),
              verticalSpace(12),
              DashboardContainer(
                title: 'اجمالي الربح',
                value: _getProfit(state),
                width: double.infinity,
              ),
            ],
          );
        } else if (state.status.isGetStatisticsFailure) {
          return CustomFailureWidget(text: state.errorMessage);
        }
        return const CustomLoadingWidget();
      },
    );
  }

  String _getProfit(StatisticsState state) {
    final revenue = state.currentPeriodData!.revenue;
    final expenses = state.currentPeriodData!.expenses;
    return (revenue - expenses).toStringAsFixed(2);
  }

  bool _buildWhen(StatisticsState state) {
    return state.status.isGetStatisticsSuccess ||
        state.status.isGetStatisticsFailure ||
        state.status.isGetStatisticsLoading;
  }
}
