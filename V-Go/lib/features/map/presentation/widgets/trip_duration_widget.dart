import 'package:flutter/material.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/map_bloc/map_state.dart';

Container tripDurationWidget(MapState state) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: const BoxDecoration(
      color: AppColors.lightWhite,
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
    child: Row(
      children: [
        Text('مدة الرحلة : ', style: AppStyle.styleRegular14),
        Text(
          state.tripDuration,
          style: AppStyle.styleMedium16.copyWith(color: AppColors.primary),
        ),
      ],
    ),
  );
}
