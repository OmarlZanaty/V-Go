import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/user_model.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../accountant/presentation/widgets/driver_finance_section.dart';
import '../widgets/driver_info.dart';

class DriverAndScooterDetailsView extends StatelessWidget {
  const DriverAndScooterDetailsView({required this.user, super.key});
  final UserModel user;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'ملفك الشخصي'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  verticalSpace(12),
                  DriverInfo(user: user),
                  verticalSpace(12),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: DriverFinanceSection(
                            profit: user.driverProfit!,
                          ),
                        ),
                        horizontalSpace(8),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.lightWhite,
                              borderRadius: BorderRadius.all(
                                Radius.circular(16),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Text(
                                    'الرحلات',
                                    style: AppStyle.styleMedium14.copyWith(
                                      color: AppColors.white,
                                    ),
                                  ),
                                  verticalSpace(8),
                                  Text(
                                    user.tripCount.toString(),
                                    style: AppStyle.styleBold24.copyWith(
                                      color: AppColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  verticalSpace(12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: AppColors.lightWhite,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 17,
                              backgroundColor: AppColors.primary,
                              child: Icon(
                                HugeIcons.strokeRoundedUser,
                                color: AppColors.black,
                                size: 20,
                              ),
                            ),
                            horizontalSpace(10),
                            Text(
                              'بيانات السائق',
                              style: AppStyle.styleMedium14.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        verticalSpace(12),
                        Row(
                          children: [
                            Expanded(
                              child: _customContainer(
                                title: 'الرقم القومى',
                                value: user.nationalId.toString(),
                              ),
                            ),
                            horizontalSpace(8),
                            _customContainer(
                              title: 'رقم الهاتف',
                              value: user.phoneNumber.toString(),
                            ),
                          ],
                        ),
                        verticalSpace(10),
                        Row(
                          children: [
                            Expanded(
                              child: _customContainer(
                                title: 'رخصة السائق',
                                value: user.license.toString(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  verticalSpace(12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: AppColors.lightWhite,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 17,
                              backgroundColor: AppColors.primary,
                              child: Icon(
                                HugeIcons.strokeRoundedScooter01,
                                color: AppColors.black,
                                size: 20,
                              ),
                            ),
                            horizontalSpace(10),
                            Text(
                              'بيانات الاسكوتر',
                              style: AppStyle.styleMedium14.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        verticalSpace(12),
                        Row(
                          children: [
                            Expanded(
                              child: _customContainer(
                                title: 'نوع الاسكوتر',
                                value: user.scooterType == 0
                                    ? 'بنزين'
                                    : 'كهرباء',
                              ),
                            ),
                            horizontalSpace(8),
                            Expanded(
                              flex: 2,
                              child: _customContainer(
                                title: 'رخصة الاسكوتر',
                                value: user.scooterType == 0
                                    ? user.scooterLicense.toString()
                                    : 'لا يوجد',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: verticalSpace(40)),
                  CustomButton(
                    text: 'تعديل الحساب',
                    onPressed: () {
                      context.pushNamed(
                        Routes.updateUserViewRoute,
                        arguments: user,
                      );
                    },
                    height: 52,
                  ),
                  verticalSpace(20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customContainer({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 6, top: 12, left: 14, right: 14),
      decoration: const BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppStyle.styleMedium12),
          verticalSpace(4),
          Text(
            value,
            style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}
