import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/helpers/convert_time.dart';
import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/current_trip_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';
import '../../../trips/data/model/new_trip_requested_for_driver_model.dart';

class CurrentTripItem extends StatelessWidget {
  const CurrentTripItem({
    required this.currentTrip,
    super.key,
    this.atClientSide = true,
  });
  final CurrentTripModel currentTrip;
  final bool atClientSide;

  NewTripRequestedForDriverModel parseModel() {
    return NewTripRequestedForDriverModel(
      tripId: currentTrip.tripId,
      tripStatus: currentTrip.tripStatus,
      startLocation: currentTrip.to,
      endLocation: currentTrip.from,
      price: currentTrip.price,
      createdAt: currentTrip.createdAt,
      client: ClientInfo(
        clientId: currentTrip.clientId,
        name: currentTrip.clientName,
        phoneNumber: currentTrip.clientPhone,
        imageUrl: currentTrip.clientImageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      onTap: () async {
        if (!atClientSide) {
          context.pushNamed(Routes.driverMapViewRoute, arguments: parseModel());
        } else {
          context.pushNamed(Routes.clientMapViewRoute, arguments: currentTrip);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          color: AppColors.darkGrey,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.only(
                    top: 4,
                    bottom: 3,
                    left: 20,
                    right: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                  ),
                  child: Text(
                    'رحلتك الحالية',
                    style: AppStyle.styleMedium14.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(
                    top: 4,
                    bottom: 3,
                    left: 16,
                    right: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                  ),
                  child: Text(
                    '${currentTrip.price.toInt()} ج.م',
                    style: AppStyle.styleMedium14.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                ),
              ],
            ),
            verticalSpace(14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.only(
                    top: 4,
                    bottom: 3,
                    left: 10,
                    right: 5,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.lightWhite,
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: Colors.green,
                      ),
                      horizontalSpace(4),
                      Text(
                        'من',
                        style: AppStyle.styleMedium12.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                horizontalSpace(6),
                Expanded(
                  child: Text(
                    currentTrip.from.address,
                    style: AppStyle.styleMedium14.copyWith(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            verticalSpace(8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.only(
                    top: 4,
                    bottom: 3,
                    left: 10,
                    right: 5,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.lightWhite,
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: Colors.red,
                      ),
                      horizontalSpace(4),
                      Text(
                        'الى',
                        style: AppStyle.styleMedium12.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                horizontalSpace(6),
                Expanded(
                  child: Text(
                    currentTrip.to.address,
                    style: AppStyle.styleMedium14.copyWith(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            verticalSpace(8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.only(
                    top: 4,
                    bottom: 3,
                    left: 10,
                    right: 5,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.lightWhite,
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timelapse_sharp,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      horizontalSpace(4),
                      Text(
                        'تاريخ الرحلة',
                        style: AppStyle.styleMedium12.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                horizontalSpace(6),
                Text(
                  convertDate(currentTrip.createdAt, includeTime: true),
                  textDirection: TextDirection.ltr,
                  style: AppStyle.styleMedium14.copyWith(color: Colors.white),
                ),
              ],
            ),
            verticalSpace(14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: AppColors.lightWhite,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                horizontalTitleGap: 14,
                leading: CustomAvatar(
                  imageUrl: !atClientSide
                      ? currentTrip.clientImageUrl
                      : currentTrip.driverImageUrl,
                  iconColor: AppColors.primary,
                ),
                title: Text(
                  !atClientSide
                      ? currentTrip.clientName
                      : currentTrip.driverName,
                  style: AppStyle.styleMedium16.copyWith(color: Colors.white),
                ),
                subtitle: SelectableText(
                  !atClientSide
                      ? currentTrip.clientPhone
                      : currentTrip.driverPhone,
                  style: AppStyle.styleRegular14.copyWith(color: Colors.white),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: !atClientSide
                            ? currentTrip.clientPhone
                            : currentTrip.driverPhone,
                      ),
                    );
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
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 22, color: Colors.amber),
                    verticalSpace(2),
                    Text(
                      !atClientSide
                          ? currentTrip.clientRate!.toStringAsFixed(1)
                          : currentTrip.driverRate!.toStringAsFixed(1),
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
    );
  }
}
