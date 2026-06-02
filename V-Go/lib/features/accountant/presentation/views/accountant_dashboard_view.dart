import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/di.dart';
import '../../../../core/helpers/double_back_to_exit.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../widgets/accountant_dashboard_body.dart';
import '../widgets/accountant_or_dispatcher_info.dart';

class AccountantDashboardView extends StatelessWidget {
  const AccountantDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExitWrapper(
      child: Scaffold(
        body: Column(
          children: [
            Container(
              decoration: const BoxDecoration(color: AppColors.lightWhite),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ).copyWith(top: 16, bottom: 10),
                child: SafeArea(
                  child: Column(
                    children: [
                      Text(
                        'لوحة تحكم المحاسب',
                        style: AppStyle.styleMedium18.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      verticalSpace(6),
                      BlocProvider(
                        create: (context) =>
                            UserCubit(getIt())
                              ..getUserDetails(AppConstants.kUserId),
                        child: BlocBuilder<UserCubit, UserState>(
                          buildWhen: (previous, current) => _buildWhen(current),
                          builder: (context, state) {
                            if (state.status.isGetUserDetailsSuccess) {
                              return AccountantOrDispatcherInfo(
                                user: state.userDetails!,
                              );
                            } else if (state.status.isGetUserDetailsFailure) {
                              return CustomFailureWidget(
                                text: state.errorMessage,
                                textColor: AppColors.white,
                              );
                            }
                            return const CustomLoadingWidget();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Expanded(child: AccountantDashboardBody()),
          ],
        ),
      ),
    );
  }

  bool _buildWhen(UserState state) =>
      state.status.isGetUserDetailsLoading ||
      state.status.isGetUserDetailsSuccess ||
      state.status.isGetUserDetailsFailure;
}
