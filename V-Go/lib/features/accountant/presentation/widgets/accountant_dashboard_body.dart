import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/statistics_cubit/statistics_cubit.dart';
import '../../../../core/utils/widgets/custom_refresh_indicator.dart';
import '../../../admin/presentation/widgets/dashboard_interactive_container.dart';
import 'finance_statistics_section.dart';

class AccountantDashboardBody extends StatelessWidget {
  const AccountantDashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomRefreshIndicator(
        onRefresh: () async {
          context.read<StatisticsCubit>().getAccountantStatistics();
        },
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  verticalSpace(10),
                  const FinanceStatisticsSection(),
                  const Divider(
                    color: AppColors.lightWhite,
                    height: 60,
                    indent: 50,
                    endIndent: 50,
                  ),
                  DashboardInteractiveContainer(
                    title: 'جميع السائقين',
                    icon: HugeIcons.strokeRoundedUserGroup,
                    onTap: () {
                      context.pushNamed(
                        Routes.allUsersViewRoute,
                        arguments: {'role': UserRole.driver},
                      );
                    },
                  ),
                  verticalSpace(12),
                  DashboardInteractiveContainer(
                    title: 'جميع الرحلات',
                    icon: HugeIcons.strokeRoundedGroupItems,
                    onTap: () {
                      context.pushNamed(Routes.allTripsViewRoute);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
