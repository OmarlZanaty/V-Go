import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

class ClientTripsCountSection extends StatelessWidget {
  const ClientTripsCountSection({
    required this.tripCount,
    required this.rating,
    super.key,
  });
  final int tripCount;
  final double rating;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SlideInRight(
            from: 200,
            child: Container(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 6,
                left: 10,
                right: 14,
              ),
              decoration: const BoxDecoration(
                color: AppColors.lightWhite,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الرحلات',
                        style: AppStyle.styleMedium14.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      const CircleAvatar(
                        backgroundColor: AppColors.lightWhite,
                        foregroundColor: AppColors.primary,
                        child: Icon(HugeIcons.strokeRoundedRoute02),
                      ),
                    ],
                  ),
                  verticalSpace(4),
                  Text(
                    tripCount.toString(),
                    style: AppStyle.styleBold24.copyWith(color: AppColors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        horizontalSpace(10),
        Expanded(
          child: SlideInLeft(
            from: 200,
            child: Container(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 6,
                left: 10,
                right: 14,
              ),
              decoration: const BoxDecoration(
                color: AppColors.lightWhite,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'التقييم',
                        style: AppStyle.styleMedium14.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      const CircleAvatar(
                        backgroundColor: AppColors.lightWhite,
                        foregroundColor: AppColors.primary,
                        child: Icon(Icons.star),
                      ),
                    ],
                  ),
                  verticalSpace(4),
                  Text(
                    rating.toString(),
                    style: AppStyle.styleBold24.copyWith(color: AppColors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
