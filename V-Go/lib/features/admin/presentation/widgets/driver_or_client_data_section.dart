import 'package:flutter/material.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';
import '../../../trips/data/model/trip_model.dart';

class DriverOrClientDataSection extends StatelessWidget {
  const DriverOrClientDataSection({
    required this.trip,
    required this.isFromDriver,
    super.key,
  });
  final TripModel trip;
  final bool isFromDriver;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFromDriver ? 'بيانات السائق' : 'بيانات العميل',
          style: AppStyle.styleMedium14.copyWith(
            color: AppColors.primary,
            height: 2,
          ),
        ),
        verticalSpace(4),
        Container(
          decoration: const BoxDecoration(
            color: AppColors.lightWhite,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 14, right: 12),
            horizontalTitleGap: 14,
            leading: CustomAvatar(
              imageUrl: isFromDriver ? trip.driverImageUrl : trip.userImageUrl,
            ),
            title: Text(
              isFromDriver ? trip.driverName ?? 'غير معروف' : trip.userName,
              style: AppStyle.styleMedium16,
            ),
            subtitle: Text(
              isFromDriver ? trip.driverPhone ?? 'غير معروف' : trip.userPhone,
              style: AppStyle.styleRegular14,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.star,
                  size: 22,
                  color: Colors.amber,
                ),
                verticalSpace(2),
                Text(
                  isFromDriver
                      ? trip.driverRate.toString()
                      : trip.userRate.toString(),
                  style: AppStyle.styleMedium14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
