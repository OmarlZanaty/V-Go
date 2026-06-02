import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../logic/cubit/captain_home_cubit.dart';

/// Panel shown while a trip is being served. The primary button advances the
/// trip through its stages: accepted -> arrived -> in progress -> completed.
class ActiveTripPanel extends StatelessWidget {
  const ActiveTripPanel({super.key, required this.state});
  final CaptainHomeState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CaptainHomeCubit>();
    final trip = state.activeTrip!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stageHeader(),
        SizedBox(height: 20.h),
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: AppColors.darkGrey,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(Icons.person, trip.client.fullName),
              SizedBox(height: 8.h),
              _row(Icons.my_location, trip.start.address,
                  color: AppColors.success),
              SizedBox(height: 8.h),
              _row(Icons.location_on, trip.end.address,
                  color: AppColors.primaryOrange),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 54.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            onPressed: state.isBusy ? null : cubit.advanceStage,
            child: state.isBusy
                ? const CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.black)
                : Text(_actionLabel(state.stage), style: AppStyle.button),
          ),
        ),
      ],
    );
  }

  Widget _stageHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(Icons.local_taxi, color: AppColors.primary, size: 22.r),
          SizedBox(width: 10.w),
          Text(_stageLabel(state.stage),
              style: AppStyle.body.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }

  String _stageLabel(TripStage stage) {
    switch (stage) {
      case TripStage.accepted:
        return 'في الطريق إلى العميل';
      case TripStage.arrived:
        return 'وصلت إلى العميل';
      case TripStage.inProgress:
        return 'الرحلة جارية';
      case TripStage.completed:
        return 'اكتملت الرحلة';
    }
  }

  String _actionLabel(TripStage stage) {
    switch (stage) {
      case TripStage.accepted:
        return 'لقد وصلت';
      case TripStage.arrived:
        return 'بدء الرحلة';
      case TripStage.inProgress:
        return 'إنهاء الرحلة';
      case TripStage.completed:
        return 'تم';
    }
  }

  Widget _row(IconData icon, String text, {Color color = AppColors.grey}) {
    return Row(
      children: [
        Icon(icon, size: 20.r, color: color),
        SizedBox(width: 10.w),
        Expanded(child: Text(text, style: AppStyle.body)),
      ],
    );
  }
}
