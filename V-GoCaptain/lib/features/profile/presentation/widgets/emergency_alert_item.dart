import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../../../../core/di/di.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import 'settings_item.dart';

/// Captain-only: long-press to send an emergency alert (with live location)
/// to dispatch via `Driver/sendAlert`.
class EmergencyAlertItem extends StatefulWidget {
  const EmergencyAlertItem({super.key});

  @override
  State<EmergencyAlertItem> createState() => _EmergencyAlertItemState();
}

class _EmergencyAlertItemState extends State<EmergencyAlertItem> {
  bool _sending = false;

  void _toast(ToastificationType type, String message) {
    if (!mounted) return;
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.fillColored,
      title: Text(message, style: AppStyle.body),
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.bottomCenter,
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final location = getIt<LocationService>();
      if (!await location.ensurePermission()) {
        _toast(ToastificationType.error, 'يجب تفعيل إذن الموقع لإرسال الطوارئ');
        return;
      }
      final pos = await location.currentPosition();
      await getIt<ApiServices>().post(
        EndPoint.sendAlert,
        data: {
          'driverId': AppConstants.kUserId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        },
      );
      _toast(ToastificationType.success, 'تم إرسال طلب الطوارئ');
    } catch (_) {
      _toast(ToastificationType.error, 'تعذّر إرسال الطلب، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsItem(
      title: 'إرسال حالة طوارئ',
      icon: Icons.emergency_share_outlined,
      color: AppColors.danger,
      onTap: () =>
          _toast(ToastificationType.info, 'اضغط مطولاً على الزر للإرسال'),
      onLongPress: _sending ? null : _send,
      trailing: _sending
          ? SizedBox(
              width: 20.r,
              height: 20.r,
              child: const CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.danger),
            )
          : Icon(Icons.touch_app_outlined, color: AppColors.grey, size: 20.r),
    );
  }
}
