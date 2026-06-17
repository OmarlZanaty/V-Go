import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../data/models/trip_offer_model.dart';
import '../logic/cubit/captain_home_cubit.dart';

/// Card shown when a new trip offer arrives — accept or reject.
class IncomingTripCard extends StatelessWidget {
  const IncomingTripCard({super.key, required this.offer, required this.isBusy});

  final TripOfferModel offer;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CaptainHomeCubit>();
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('رحلة جديدة', style: AppStyle.title),
              const Spacer(),
              Text(
                '${offer.price.toStringAsFixed(0)} ج.م',
                style: AppStyle.title.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _row(Icons.person, offer.client.fullName),
          _row(Icons.star, '${offer.client.rating.toStringAsFixed(1)} تقييم'),
          const Divider(color: AppColors.grey, height: 28),
          _row(Icons.my_location, offer.start.displayAddress, color: AppColors.success),
          SizedBox(height: 10.h),
          _row(Icons.location_on, offer.end.displayAddress, color: AppColors.primaryOrange),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  onPressed: isBusy ? null : cubit.rejectOffer,
                  child: Text('رفض',
                      style: AppStyle.body.copyWith(color: AppColors.danger)),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  onPressed: isBusy ? null : cubit.acceptOffer,
                  child: isBusy
                      ? SizedBox(
                          height: 20.r,
                          width: 20.r,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.black),
                        )
                      : Text('قبول', style: AppStyle.button),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text, {Color color = AppColors.grey}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 20.r, color: color),
          SizedBox(width: 10.w),
          Expanded(child: Text(text, style: AppStyle.body)),
        ],
      ),
    );
  }
}
