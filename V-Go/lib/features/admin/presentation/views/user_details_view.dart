import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/get_gender.dart';
import '../../../../core/helpers/role_converter.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../accountant/presentation/widgets/driver_finance_section.dart';
import '../widgets/block_and_unblock_button.dart';
import '../widgets/delete_user_button.dart';
import '../widgets/user_details_list_tile.dart';

class UserDetailsView extends StatelessWidget {
  const UserDetailsView({super.key, this.isDriver = false});
  final bool isDriver;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: isDriver ? 'تفاصيل السائق' : 'تفاصيل العميل'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: BlocBuilder<UserCubit, UserState>(
                buildWhen: (previous, current) => _buildWhen(current),
                builder: (context, state) {
                  if (state.status.isGetUserDetailsSuccess) {
                    return Column(
                      children: [
                        verticalSpace(10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.lightWhite,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(
                              left: 10,
                              right: 10,
                              top: 2,
                              bottom: 2,
                            ),
                            leading: CustomAvatar(
                              imageUrl: state.userDetails!.profilePicture,
                              radius: 28,
                            ),
                            title: Text(
                              state.userDetails!.name,
                              style: AppStyle.styleMedium16.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                            subtitle: Text(
                              state.userDetails!.email ??
                                  'لا يوجد بريد إلكتروني',
                              style: AppStyle.styleRegular14.copyWith(
                                color: AppColors.lightGrey,
                              ),
                            ),
                            trailing:
                                AppConstants.kRole == UserRole.admin.capitalized
                                ? IconButton(
                                    onPressed: () async {
                                      final result = await context.pushNamed(
                                        Routes.updateUserViewRoute,
                                        arguments: state.userDetails,
                                      );
                                      if (result != null &&
                                          result == true &&
                                          context.mounted) {
                                        context
                                            .read<UserCubit>()
                                            .getUserDetails(
                                              state.userDetails!.id,
                                              isDriver:
                                                  state.userDetails!.role ==
                                                  UserRole.driver.capitalized,
                                            );
                                      }
                                    },
                                    icon: const Icon(Icons.edit),
                                    style: IconButton.styleFrom(
                                      padding: const EdgeInsets.all(10),
                                      foregroundColor: AppColors.primary,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        verticalSpace(14),
                        UserDetailsListTile(
                          title: 'رقم الهاتف',
                          value:
                              state.userDetails!.phoneNumber ??
                              'لا يوجد رقم هاتف',
                        ),
                        UserDetailsListTile(
                          title: 'الجنس',
                          value: getGender(state.userDetails!.gender),
                        ),
                        UserDetailsListTile(
                          title: 'الوظيفة',
                          value: roleConverter(state.userDetails!.role),
                        ),
                        if (state.userDetails!.role ==
                                UserRole.client.capitalized ||
                            state.userDetails!.role ==
                                UserRole.driver.capitalized)
                          UserDetailsListTile(
                            title: 'عدد الرحلات',
                            value:
                                state.userDetails!.tripCount?.toString() ?? '0',
                            trailing: 'عرض الرحلات',
                            onTap: () {
                              if (state.userDetails?.tripCount == 0) {
                                infoToast(
                                  context,
                                  'لا يوجد رحلات',
                                  'لا توجد رحلات لهذا المستخدم',
                                );
                                return;
                              }
                              context.pushNamed(
                                Routes.allTripsViewRoute,
                                arguments: state.userDetails!.id,
                              );
                            },
                          ),
                        if (state.userDetails!.role ==
                            UserRole.driver.capitalized) ...[
                          verticalSpace(8),
                          DriverFinanceSection(
                            profit: state.userDetails!.driverProfit!,
                          ),
                          verticalSpace(8),
                        ],

                        const Divider(color: AppColors.lightWhite),
                        if (state.userDetails!.role !=
                            UserRole.client.capitalized)
                          UserDetailsListTile(
                            title: 'الرقم القومي',
                            value:
                                state.userDetails!.nationalId ??
                                'لا يوجد رقم قومي',
                          ),
                        if (state.userDetails!.role ==
                            UserRole.driver.capitalized)
                          Column(
                            children: [
                              UserDetailsListTile(
                                title: 'رخصة الاسكوتر',
                                value:
                                    state.userDetails!.license ??
                                    'لا يوجد رخصة',
                              ),

                              UserDetailsListTile(
                                title: 'نوع الاسكوتر',
                                value: state.userDetails?.scooterType == 1
                                    ? 'كهرباء'
                                    : 'بنزين',
                              ),
                              UserDetailsListTile(
                                title: 'رخصة الاسكوتر',
                                value: state.userDetails?.scooterType == 0
                                    ? state.userDetails!.scooterLicense
                                          .toString()
                                    : 'لا يوجد رخصة',
                              ),
                            ],
                          ),
                        if (AppConstants.kRole ==
                            UserRole.admin.capitalized) ...[
                          Expanded(child: verticalSpace(40)),
                          Row(
                            children: [
                              Expanded(
                                child: DeleteUserButton(
                                  userId: state.userDetails!.id,
                                ),
                              ),
                              horizontalSpace(8),
                              Expanded(
                                child: BlockButton(
                                  userId: state.userDetails!.id,
                                  isBlocked:
                                      state.userDetails?.isBlocked ?? false,
                                ),
                              ),
                            ],
                          ),
                        ],
                        verticalSpace(16),
                      ],
                    );
                  } else if (state.status.isGetUserDetailsFailure) {
                    return CustomFailureWidget(text: state.errorMessage);
                  }
                  return const CustomLoadingWidget();
                },
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
