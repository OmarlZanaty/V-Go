import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';

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
        SizedBox(height: 12.h),
        _priceBanner(),
        SizedBox(height: 12.h),
        SizedBox(
          height: 48.h,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              // Solid dark fill so the yellow label is legible over the map.
              backgroundColor: AppColors.darkGrey,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            onPressed: () => _openNavigation(context, state),
            icon: Icon(Icons.navigation_outlined, size: 20.r),
            label: Text(
              state.stage == TripStage.inProgress
                  ? 'الملاحة إلى الوجهة'
                  : 'الملاحة إلى العميل',
              style: AppStyle.body.copyWith(color: AppColors.primary),
            ),
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
            onPressed: state.isBusy ? null : _onPressed(cubit, state),
            child: state.isBusy
                ? const CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.black)
                : Text(_buttonLabel(state), style: AppStyle.button),
          ),
        ),
      ],
    );
  }

  /// Big, clear fare display. Emphasised once the ride ends so the captain
  /// sees exactly how much to collect.
  Widget _priceBanner() {
    final price = state.activeTrip?.price ?? 0;
    final isCompleted = state.stage == TripStage.completed;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isCompleted ? 16.h : 12.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isCompleted ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            isCompleted ? 'المبلغ المطلوب' : 'قيمة الرحلة',
            style: AppStyle.hint.copyWith(color: AppColors.white),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${price.ceil()}',
                style: GoogleFonts.cairo(
                  fontSize: isCompleted ? 40.sp : 28.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                'ج.م',
                style: GoogleFonts.cairo(
                  fontSize: isCompleted ? 20.sp : 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stageHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        // Solid dark background so the status stays readable over the light map
        // (the old translucent yellow blended into the map and was invisible).
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.primary, width: 1.5),
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

  /// At the completed stage the captain settles payment: confirm cash, re-check
  /// the client's visa payment, or — if already paid — just finish.
  VoidCallback _onPressed(CaptainHomeCubit cubit, CaptainHomeState state) {
    if (state.stage == TripStage.completed) {
      if (state.activeTripPaid) return cubit.finishTrip;
      return (state.activeTrip?.isVisa ?? false)
          ? () => cubit.recheckActivePayment(showFeedback: true)
          : cubit.confirmCashPayment;
    }
    return cubit.advanceStage;
  }

  String _buttonLabel(CaptainHomeState state) {
    if (state.stage == TripStage.completed) {
      if (state.activeTripPaid) return 'تم';
      return (state.activeTrip?.isVisa ?? false)
          ? 'تحقّق من دفع العميل'
          : 'تأكيد استلام الدفع';
    }
    return _actionLabel(state.stage);
  }

  /// Opens turn-by-turn navigation in Google Maps to the current target — the
  /// client's pickup before the ride starts, the destination once it's running.
  Future<void> _openNavigation(
      BuildContext context, CaptainHomeState state) async {
    final trip = state.activeTrip;
    if (trip == null) return;
    final target = state.stage == TripStage.inProgress ? trip.end : trip.start;

    // Prefer the Google Maps navigation intent; fall back to a maps URL.
    final navUri = Uri.parse('google.navigation:q=${target.lat},${target.lng}&mode=d');
    final webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${target.lat},${target.lng}&travelmode=driving');

    var launched = false;
    if (await canLaunchUrl(navUri)) {
      launched = await launchUrl(navUri, mode: LaunchMode.externalApplication);
    }
    if (!launched) {
      launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
    if (!launched && context.mounted) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: Text('تعذّر فتح تطبيق الخرائط', style: AppStyle.body),
        autoCloseDuration: const Duration(seconds: 3),
        alignment: Alignment.bottomCenter,
      );
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
