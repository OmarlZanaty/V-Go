import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/double_back_to_exit.dart';
import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../accountant/presentation/widgets/accountant_or_dispatcher_info.dart';

class DispatcherDashboardView extends StatelessWidget {
  const DispatcherDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExitWrapper(
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          tooltip: 'خدمة العملاء',
          onPressed: () {
            context.pushNamed(Routes.allDispatcherChatsViewRoute);
          },
          backgroundColor: AppColors.primary,
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedCustomerSupport,
            color: AppColors.black,
            size: 28,
          ),
        ),
        body: Column(
          children: [
            Container(
              decoration: const BoxDecoration(color: AppColors.lightWhite),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ).copyWith(top: 20, bottom: 10),
                child: SafeArea(
                  child: Column(
                    children: [
                      Text(
                        'لوحة تحكم الموزع',
                        style: AppStyle.styleMedium18.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      verticalSpace(10),
                      BlocBuilder<UserCubit, UserState>(
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
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  verticalSpace(16),
                  InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    onTap: () {
                      context.pushNamed(Routes.allAvailableDriversViewRoute);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: const BoxDecoration(
                        color: AppColors.lightWhite,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primary,
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedUserGroup03,
                              color: AppColors.black,
                              size: 28,
                            ),
                          ),
                          verticalSpace(12),
                          Text(
                            'جميع السائقين المتاحين',
                            style: AppStyle.styleMedium16.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  verticalSpace(12),
                  InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    onTap: () {
                      context.pushNamed(Routes.clientMapViewRoute);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: const BoxDecoration(
                        color: AppColors.lightWhite,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primary,
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedLocationAdd01,
                              color: AppColors.black,
                              size: 28,
                            ),
                          ),
                          verticalSpace(12),
                          Text(
                            'اضافة طلب جديد',
                            style: AppStyle.styleMedium16.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  verticalSpace(12),
                  InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    onTap: () {
                      context.pushNamed(Routes.allCurrentTripsViewRoute);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: const BoxDecoration(
                        color: AppColors.lightWhite,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primary,
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedRoute03,
                              color: AppColors.black,
                              size: 28,
                            ),
                          ),
                          verticalSpace(12),
                          Text(
                            'عرض الطلبات الحالية',
                            style: AppStyle.styleMedium16.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
