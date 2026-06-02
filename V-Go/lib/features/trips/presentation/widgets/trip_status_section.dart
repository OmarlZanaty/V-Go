import 'package:flutter/material.dart';

import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';

class TripStatusSection extends StatelessWidget {
  const TripStatusSection({
    required this.status,
    required this.tripId,
    super.key,
  });
  final String status;
  final String tripId;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: tripStatusColor(status).withValues(alpha: 0.18),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Text(
        _getStatus(status),
        style: AppStyle.styleMedium18.copyWith(color: tripStatusColor(status)),
      ),
    );
  }

  String _getStatus(String status) {
    switch (status) {
      case 'Pending':
        return 'بانتظار الموافقة';
      case 'Accepted':
        return 'الرحلة مقبولة';
      case 'Arrived':
        return 'السائق وصل للعميل';
      case 'Rejected':
        return 'الرحلة مرفوضة';
      case 'Completed':
        return 'الرحلة مكتملة';
      case 'Canceled':
        return 'الرحلة ملغاة';
      case 'InProgress':
        return 'الرحلة قيد التنفيذ';
      default:
        return 'حالة غير معروفة';
    }
  }
}
