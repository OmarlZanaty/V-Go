import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theming/app_colors.dart';
import '../../../core/theming/app_style.dart';
import '../services/navigation_engine.dart';
import '../utils/distance_helper.dart';
import 'maneuver_icon.dart';

/// Top overlay: large maneuver arrow + Arabic instruction + distance to the turn.
/// RTL, animates when the step changes.
class InstructionBanner extends StatelessWidget {
  const InstructionBanner({super.key, required this.update});

  /// Latest engine snapshot; null while the route is still loading.
  final NavUpdate? update;

  @override
  Widget build(BuildContext context) {
    final step = update?.currentStep;
    final maneuver = step?.maneuver ?? 'DEPART';
    // Prefer Google's (Arabic) instruction text; fall back to our phrase.
    final text = (step?.instruction.isNotEmpty ?? false)
        ? step!.instruction
        : ManeuverIcon.arabicPhrase(maneuver);
    final distance =
        update == null ? '' : DistanceHelper.formatDistance(update!.distanceToManeuver);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.25),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: Container(
          // Key on step index so AnimatedSwitcher animates on each new step.
          key: ValueKey<int>(update?.stepIndex ?? -1),
          margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Center(
                  child: ManeuverIcon(
                    maneuver: maneuver,
                    size: 34.r,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (distance.isNotEmpty)
                      Text(
                        distance,
                        style: AppStyle.heading.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    SizedBox(height: 2.h),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.title.copyWith(color: AppColors.black),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
