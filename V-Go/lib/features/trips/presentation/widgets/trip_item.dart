import 'package:flutter/material.dart';

import '../../../../core/helpers/convert_time.dart';
import '../../../../core/helpers/get_trip_status.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../data/model/trip_model.dart';

class TripItem extends StatelessWidget {
  const TripItem({required this.trip, super.key, this.onTap});
  final TripModel trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.lightWhite,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    trip.from.address,
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
                    trip.to.address,
                    style: AppStyle.styleMedium14.copyWith(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            verticalSpace(12),
            Row(
              children: [
                Text('تاريخ الانشاء :', style: AppStyle.styleMedium12),
                horizontalSpace(6),
                Text(
                  convertDate(trip.createdAt, includeTime: true),
                  textDirection: TextDirection.ltr,
                  style: AppStyle.styleMedium14,
                ),
              ],
            ),
            verticalSpace(12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.lightWhite,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: tripInfoColumn(
                      title: 'المسافة',
                      value: '${trip.distanceKm.toStringAsFixed(2)} كم',
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child: VerticalDivider(color: AppColors.lightGrey),
                  ),
                  Expanded(
                    child: tripInfoColumn(
                      title: 'الحالة',
                      value: trip.status,
                      isTripStatus: true,
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child: VerticalDivider(color: AppColors.lightGrey),
                  ),
                  Expanded(
                    child: tripInfoColumn(
                      title: 'السعر',
                      value: '${trip.price.ceil()} ج.م',
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

  Widget tripInfoColumn({
    required String title,
    required String value,
    bool isTripStatus = false,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: AppStyle.styleRegular12.copyWith(color: AppColors.white),
        ),
        verticalSpace(5),
        isTripStatus
            ? Container(
                padding: const EdgeInsets.only(
                  top: 3,
                  bottom: 2,
                  left: 12,
                  right: 12,
                ),
                decoration: BoxDecoration(
                  color: tripStatusColor(value).withValues(alpha: 0.18),
                  borderRadius: const BorderRadius.all(Radius.circular(25)),
                ),
                child: Text(
                  getTripStatus(value),
                  style: AppStyle.styleMedium12.copyWith(
                    color: tripStatusColor(value),
                  ),
                ),
              )
            : Text(
                value,
                style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
              ),
      ],
    );
  }
}
