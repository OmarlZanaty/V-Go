import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/convert_time.dart';
import '../../../../core/helpers/double_back_to_exit.dart';
import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/realtime_driver_cubit/driver_cubit.dart';
import '../../../../core/utils/logic/realtime_driver_cubit/driver_extension.dart';
import '../../../../core/utils/logic/statistics_cubit/statistics_cubit.dart';
import '../../../../core/utils/model/driver_alert_model.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_refresh_indicator.dart';
import '../widgets/admin_drawer.dart';
import '../widgets/change_driver_commission_section.dart';
import '../widgets/change_kilo_price_section.dart';
import '../widgets/dashboard_container.dart';
import '../widgets/dashboard_interactive_container.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});
  bool _buildWhen(StatisticsState current) {
    return current.status.isGetStatisticsFailure ||
        current.status.isGetStatisticsLoading ||
        current.status.isGetStatisticsSuccess;
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExitWrapper(
      child: BlocListener<DriverCubit, DriverState>(
        listener: (context, state) {
          if (state.status.isReceiveAlert) {
            _showDriverAlertDialog(context, state.driverAlert!);
          }
        },
        child: Scaffold(
          appBar: customAppBar(title: 'لوحة تحكم الادمن'),
          drawer: const AdminDrawer(),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomRefreshIndicator(
              onRefresh: () async {
                context.read<StatisticsCubit>().getAdminStatistics();
              },
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: BlocBuilder<StatisticsCubit, StatisticsState>(
                      buildWhen: (previous, current) => _buildWhen(current),
                      builder: (context, state) {
                        if (state.status.isGetStatisticsSuccess) {
                          return Column(
                            children: [
                              verticalSpace(6),
                              Row(
                                children: [
                                  Expanded(
                                    child: DashboardContainer(
                                      title: 'عدد السائقين',
                                      value:
                                          state.adminStatistics?.drivers ?? '0',
                                      onTap: () {
                                        context.pushNamed(
                                          Routes.allUsersViewRoute,
                                          arguments: {
                                            'role': UserRole.driver,
                                            'fromAccountantDashboard': false,
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  horizontalSpace(10),
                                  Expanded(
                                    child: DashboardContainer(
                                      title: 'عدد العملاء',
                                      value:
                                          state.adminStatistics?.clients ?? '0',
                                      onTap: () {
                                        context.pushNamed(
                                          Routes.allUsersViewRoute,
                                          arguments: {
                                            'role': UserRole.client,
                                            'fromAccountantDashboard': false,
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              verticalSpace(10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DashboardContainer(
                                      title: 'عدد المحاسبين',
                                      value:
                                          state.adminStatistics?.accountants ??
                                          '0',
                                      onTap: () {
                                        context.pushNamed(
                                          Routes.allUsersViewRoute,
                                          arguments: {
                                            'role': UserRole.accountant,
                                            'fromAccountantDashboard': false,
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  horizontalSpace(10),
                                  Expanded(
                                    child: DashboardContainer(
                                      title: 'عدد الموزعين',
                                      value:
                                          state.adminStatistics?.dispatchers ??
                                          '0',
                                      onTap: () {
                                        context.pushNamed(
                                          Routes.allUsersViewRoute,
                                          arguments: {
                                            'role': UserRole.dispatcher,
                                            'fromAccountantDashboard': false,
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              verticalSpace(10),
                              DashboardContainer(
                                title: 'اجمالي عدد الرحلات',
                                value: state.adminStatistics?.trips ?? '0',
                                width: double.infinity,
                                onTap: () {
                                  context.pushNamed(Routes.allTripsViewRoute);
                                },
                              ),
                              const Divider(
                                color: AppColors.lightWhite,
                                height: 36,
                                endIndent: 40,
                                indent: 40,
                                thickness: 1,
                              ),
                              DashboardInteractiveContainer(
                                title: 'اضافة محاسب',
                                icon: HugeIcons.strokeRoundedAddMale,
                                onTap: () async {
                                  final result = await context.pushNamed(
                                    Routes.addDispatcherOrAccountantViewRoute,
                                    arguments: true,
                                  );
                                  if (result == true && context.mounted) {
                                    context
                                        .read<StatisticsCubit>()
                                        .getAdminStatistics();
                                  }
                                },
                              ),
                              verticalSpace(10),
                              DashboardInteractiveContainer(
                                title: 'اضافة موزع',
                                icon: HugeIcons.strokeRoundedAddMale,
                                onTap: () async {
                                  final result = await context.pushNamed(
                                    Routes.addDispatcherOrAccountantViewRoute,
                                    arguments: false,
                                  );
                                  if (result == true && context.mounted) {
                                    context
                                        .read<StatisticsCubit>()
                                        .getAdminStatistics();
                                  }
                                },
                              ),

                              verticalSpace(10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ChangeKiloPriceSection(
                                      currentPrice:
                                          state.adminStatistics?.kiloPrice ??
                                          '0',
                                    ),
                                  ),
                                  horizontalSpace(8),
                                  Expanded(
                                    child: ChangeDriverCommissionSection(
                                      currentPercentage:
                                          state
                                              .adminStatistics
                                              ?.driverCommission ??
                                          '0',
                                    ),
                                  ),
                                ],
                              ),
                              verticalSpace(10),
                              DashboardInteractiveContainer(
                                title: 'عرض السائقين المتاحين',
                                icon: HugeIcons.strokeRoundedGroupItems,
                                onTap: () {
                                  context.pushNamed(
                                    Routes.allAvailableDriversViewRoute,
                                  );
                                },
                              ),
                              verticalSpace(10),
                              DashboardInteractiveContainer(
                                title: 'المحاسبة',
                                icon: HugeIcons.strokeRoundedWallet02,
                                onTap: () {
                                  context.pushNamed(
                                    Routes.accountantDataForAdminViewRoute,
                                  );
                                },
                              ),
                              Expanded(child: verticalSpace(10)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(60),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          context.pushNamed(
                                            Routes.clientMapViewRoute,
                                          );
                                        },
                                        child: Text(
                                          'اطلب رحلة',
                                          style: AppStyle.styleMedium16
                                              .copyWith(color: AppColors.black),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 30,
                                      child: VerticalDivider(
                                        color: Colors.black,
                                        thickness: 1.2,
                                        width: 0,
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          context.pushNamed(
                                            Routes.allCurrentTripsViewRoute,
                                          );
                                        },
                                        child: Text(
                                          'الرحلات الحالية',
                                          style: AppStyle.styleMedium16
                                              .copyWith(color: AppColors.black),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              verticalSpace(16),
                            ],
                          );
                        } else if (state.status.isGetStatisticsFailure) {
                          return SizedBox(
                            height: 0.9.sh,
                            child: CustomFailureWidget(
                              text: state.errorMessage,
                              onRetry: () => context
                                  .read<StatisticsCubit>()
                                  .getAdminStatistics(),
                            ),
                          );
                        }
                        return SizedBox(
                          height: 0.9.sh,
                          child: const CustomLoadingWidget(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDriverAlertDialog(BuildContext context, DriverAlertModel alert) {
    AwesomeDialog(
      context: context,
      animType: AnimType.rightSlide,
      dialogType: DialogType.warning,
      dismissOnBackKeyPress: false,
      dismissOnTouchOutside: false,
      padding: EdgeInsets.zero,
      dialogBackgroundColor: AppColors.darkGrey,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              child: Text(
                'تنبيه طوارئ من سائق',
                style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
              ),
            ),
            verticalSpace(14),
            Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                color: AppColors.lightWhite,
              ),
              child: ListTile(
                horizontalTitleGap: 14,
                contentPadding: const EdgeInsets.only(right: 10, left: 10),
                leading: CustomAvatar(imageUrl: alert.driverProfilePicture),
                title: Text(
                  alert.driverName,
                  style: AppStyle.styleMedium16.copyWith(
                    color: AppColors.white,
                  ),
                ),
                subtitle: Text(
                  alert.driverPhone,
                  style: AppStyle.styleRegular14.copyWith(
                    color: AppColors.white,
                  ),
                ),
                trailing: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: alert.driverPhone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        width: 180,
                        backgroundColor: AppColors.primary,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        content: Text(
                          'تم نسخ رقم الهاتف',
                          style: AppStyle.styleMedium12.copyWith(
                            color: AppColors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy, color: AppColors.primary),
                ),
              ),
            ),
            verticalSpace(14),
            FutureBuilder(
              future: LocationService().getAddressFromCoordinates(
                alert.latitude,
                alert.longitude,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CustomLoadingWidget();
                } else if (snapshot.hasError) {
                  return Text(
                    'الموقع: غير متوفر',
                    style: AppStyle.styleMedium14.copyWith(
                      color: AppColors.white,
                    ),
                  );
                } else {
                  return Text(
                    'الموقع: ${snapshot.data}',
                    style: AppStyle.styleMedium14.copyWith(
                      color: AppColors.white,
                    ),
                  );
                }
              },
            ),
            verticalSpace(14),
            Text(
              convertDate(alert.alerttime, includeTime: true),
              style: AppStyle.styleRegular14.copyWith(color: AppColors.white),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
      btnOkText: 'حسنا',
      btnOkOnPress: () {},
      buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: AppColors.white),
    ).show();
  }
}
