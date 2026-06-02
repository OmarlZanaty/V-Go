import 'package:flutter/material.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../admin/presentation/widgets/driver_or_client_data_section.dart';
import '../../data/model/trip_model.dart';
import '../widgets/trip_item.dart';
import '../widgets/trip_status_section.dart';

class TripDetailsView extends StatelessWidget {
  const TripDetailsView({required this.trip, super.key});
  final TripModel trip;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'تفاصيل الرحلة'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  verticalSpace(20),
                  Text(
                    'بيانات الرحلة',
                    style: AppStyle.styleMedium14.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  verticalSpace(10),
                  TripItem(trip: trip),
                  verticalSpace(24),
                  DriverOrClientDataSection(trip: trip, isFromDriver: false),
                  verticalSpace(24),
                  DriverOrClientDataSection(trip: trip, isFromDriver: true),
                  Expanded(child: verticalSpace(30)),
                  TripStatusSection(status: trip.status, tripId: trip.tripId),
                  verticalSpace(20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
