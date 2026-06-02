import 'package:flutter/material.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/current_trip_model.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import 'driver_data_widget.dart';
import 'payment_options_section.dart';

Widget arrivedDriverSection(
  RealTimeTripState tripState,
  BuildContext context, {
  CurrentTripModel? currentTrip,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 16),
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
        Container(
          padding: const EdgeInsets.only(
            top: 6,
            bottom: 4,
            left: 16,
            right: 16,
          ),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.all(Radius.circular(50)),
          ),
          child: Text(
            'وصل السائق لموقعك',
            style: AppStyle.styleMedium12.copyWith(color: AppColors.black),
          ),
        ),
        verticalSpace(10),
        driverDataWidget(currentTrip: currentTrip, context: context),
        paymentOptionsSection(context, tripState, currentTrip: currentTrip),
        verticalSpace(4),
      ],
    ),
  );
}
