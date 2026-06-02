import 'dart:core';

import 'package:flutter/material.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/current_trip_model.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../logic/map_bloc/map_state.dart';
import 'driver_data_widget.dart';
import 'payment_options_section.dart';

// 💡 دالة مساعدة لتهيئة الوقت (تظهر الدقائق والثواني لرؤية التحديث)
String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hoursس $minutesد $secondsث';
  } else if (minutes > 0) {
    return '$minutes د ';
  } else if (seconds > 0) {
    return 'اقل من دقيقة';
  }
  return 'اقل من دقيقة';
}
// ------------------------------------------------------------------

Widget startTripSection(
  MapState state,
  RealTimeTripState tripState,
  BuildContext context, {
  CurrentTripModel? currentTrip,
}) {
  final remainingTime = state.remainingTime;
  final formattedTime = (remainingTime != null)
      ? _formatDuration(remainingTime)
      : null;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: const BoxDecoration(
      color: AppColors.darkGrey,
      borderRadius: BorderRadius.all(Radius.circular(18)),
      boxShadow: [
        BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.only(
                top: 6,
                bottom: 4,
                left: 16,
                right: 16,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.all(Radius.circular(50)),
              ),
              child: Text(
                'الرحلة قيد التنفيذ',
                style: AppStyle.styleMedium12.copyWith(color: AppColors.white),
              ),
            ),
            if (formattedTime != null)
              Container(
                padding: const EdgeInsets.only(
                  top: 6,
                  bottom: 4,
                  left: 12,
                  right: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightWhite,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'الوقت المتبقي : ',
                      style: AppStyle.styleMedium12.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    horizontalSpace(3),
                    Text(
                      formattedTime, // استخدام الوقت المنسق
                      style: AppStyle.styleMedium12.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        verticalSpace(12),
        driverDataWidget(currentTrip: currentTrip, context: context),
        paymentOptionsSection(context, tripState, currentTrip: currentTrip),
      ],
    ),
  );
}
