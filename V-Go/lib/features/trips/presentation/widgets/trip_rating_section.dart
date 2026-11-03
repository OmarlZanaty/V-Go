import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/rating_cubit/rating_cubit.dart';
import '../../../../core/utils/model/send_rating_model.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../data/model/trip_model.dart';
import 'rating_bar_section.dart';

/// Rating for a finished trip, offered on the trip's own page.
///
/// The live completion screen is the only other place to rate, and it is gone
/// as soon as the rider leaves it (or never appears when the app missed the
/// live event), which left riders with no way to rate the ride at all.
class TripRatingSection extends StatefulWidget {
  const TripRatingSection({required this.trip, super.key});

  final TripModel trip;

  static bool isAvailableFor(TripModel trip) =>
      trip.status == 'Completed' &&
      !trip.isRatedByMe &&
      (trip.driverId?.isNotEmpty ?? false);

  @override
  State<TripRatingSection> createState() => _TripRatingSectionState();
}

class _TripRatingSectionState extends State<TripRatingSection> {
  double _rating = 0;
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
          horizontalSpace(6),
          Text(
            'تم إرسال تقييمك، شكرًا لك',
            style: AppStyle.styleMedium12.copyWith(color: AppColors.primary),
          ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            'قيّم رحلتك',
            style: AppStyle.styleMedium14.copyWith(color: AppColors.primary),
          ),
          verticalSpace(10),
          RatingBarSection(
            isDriver: false,
            onRatingUpdate: (value) => setState(() => _rating = value),
          ),
          verticalSpace(14),
          BlocConsumer<RatingCubit, RatingState>(
            listener: (context, state) {
              if (state.status.isSendRatingSuccess) {
                successToast(context, 'عملية ناجحة', 'تم ارسال التقييم بنجاح');
                setState(() => _sent = true);
              } else if (state.status.isSendRatingFailure) {
                errorToast(context, 'حدث خطا', state.errMessage);
              }
            },
            builder: (context, state) {
              if (state.status.isSendRatingLoading) {
                return const CustomLoadingWidget();
              }
              return CustomButton(
                text: 'ارسال التقييم',
                height: 50,
                width: 0.45.sw,
                onPressed: () {
                  if (_rating < 1) {
                    errorToast(context, 'التقييم', 'اختر عدد النجوم أولًا');
                    return;
                  }
                  context.read<RatingCubit>().sendRating(
                    SendRatingModel(
                      score: _rating.ceil(),
                      tripId: widget.trip.tripId,
                      fromUserId: AppConstants.kUserId,
                      toUserId: widget.trip.driverId ?? '',
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
