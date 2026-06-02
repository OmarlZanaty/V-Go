import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../logic/realtime_trip_cubit/realtime_trip_extension.dart';
import 'requested_trip_item.dart';

class NewTripsSection extends StatelessWidget {
  const NewTripsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RealTimeTripCubit, RealTimeTripState>(
      buildWhen: (previous, current) =>
          current.status.isNewRequestedTripsForDriver,
      builder: (context, state) {
        if (state.tripRequestedListForDriver.isNotEmpty) {
          final length = state.tripRequestedListForDriver.length;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 10),
            itemCount: length,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RequestedTripItem(
                  newTrip: state.tripRequestedListForDriver[length - index - 1],
                ),
              );
            },
          );
        }
        return ListView(
          children: [
            Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الطلبات المتاحة',
                  style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
                  textAlign: TextAlign.center,
                ),
                verticalSpace(16),
                SizedBox(
                  width: double.infinity,
                  height: 240,
                  child: DottedBorder(
                    options: RoundedRectDottedBorderOptions(
                      radius: const Radius.circular(20),
                      color: Colors.grey[800]!,
                      strokeWidth: 1.5,
                      dashPattern: [5, 5],
                    ),
                    child: Align(
                      child: Text(
                        'لا توجد طلبات جديدة حالياً',
                        style: AppStyle.styleMedium16.copyWith(
                          color: AppColors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        );
      },
    );
  }
}
