import 'package:flutter/material.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/get_gender.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/available_driver_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';

class AvailableDriverItem extends StatelessWidget {
  const AvailableDriverItem({required this.driver, super.key});
  final AvailableDriverModel driver;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: ListTile(
        onTap: () {
          context.pushNamed(
            Routes.userDetailsViewRoute,
            arguments: {'userId': driver.driverId, 'isDriver': true},
          );
        },
        leading: CustomAvatar(imageUrl: driver.profilePhoto),
        title: Text(
          driver.driverName,
          style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
        ),
        subtitle: Text(
          getGender(driver.driverGender),
          style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}
