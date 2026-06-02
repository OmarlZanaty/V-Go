import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

class RatingBarSection extends StatelessWidget {
  const RatingBarSection({
    required this.onRatingUpdate,
    this.isDriver = true,
    super.key,
  });

  final bool isDriver;
  final void Function(double) onRatingUpdate;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RatingBar.builder(
          minRating: 1,
          itemPadding: const EdgeInsets.symmetric(horizontal: 3.0),
          itemBuilder: (__, _) => const Icon(Icons.star, color: Colors.amber),
          onRatingUpdate: onRatingUpdate,
        ),
        verticalSpace(16),
        Text(
          'شاركنا رأيك حول تعاملك مع ${!isDriver ? 'السائق' : 'العميل'}.',
          style: AppStyle.styleMedium12.copyWith(
            fontStyle: FontStyle.italic,
            color: AppColors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
