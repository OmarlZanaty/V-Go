import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theming/app_colors.dart';
import '../../../core/theming/app_style.dart';
import '../services/navigation_engine.dart';
import '../utils/distance_helper.dart';

/// Bottom bar: phase label, remaining distance + ETA, and Cancel / SOS actions.
class EtaBar extends StatelessWidget {
  const EtaBar({
    super.key,
    required this.update,
    required this.phaseLabel,
    required this.onCancel,
    required this.onSos,
  });

  final NavUpdate? update;
  final String phaseLabel;
  final VoidCallback onCancel;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    final remainingDist =
        update == null ? '—' : DistanceHelper.formatDistance(update!.remainingDistance);
    final eta =
        update == null ? '—' : DistanceHelper.etaClock(update!.remainingDuration);
    final remainingTime =
        update == null ? '' : DistanceHelper.formatDuration(update!.remainingDuration);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
        decoration: BoxDecoration(
          color: AppColors.darkGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.grey,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppColors.primary, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag, size: 16.r, color: AppColors.primary),
                        SizedBox(width: 6.w),
                        Text(phaseLabel,
                            style: AppStyle.body.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    remainingTime.isEmpty ? '' : 'الوصول $eta',
                    style: AppStyle.hint,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  _metric(Icons.straighten, remainingDist, 'المسافة'),
                  SizedBox(width: 12.w),
                  _metric(Icons.access_time, remainingTime.isEmpty ? '—' : remainingTime,
                      'الوقت'),
                  const Spacer(),
                  _circleButton(
                    icon: Icons.sos,
                    color: AppColors.danger,
                    onTap: onSos,
                  ),
                  SizedBox(width: 10.w),
                  _circleButton(
                    icon: Icons.close,
                    color: AppColors.grey,
                    onTap: onCancel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20.r, color: AppColors.primary),
        SizedBox(width: 6.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: AppStyle.title.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: AppStyle.hint.copyWith(fontSize: 10.sp)),
          ],
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        width: 46.w,
        height: 46.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.4),
        ),
        child: Icon(icon, color: color, size: 22.r),
      ),
    );
  }
}
