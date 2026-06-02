import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../data/models/trip_model.dart';

class TripDetailsView extends StatelessWidget {
  const TripDetailsView({super.key, required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل الرحلة',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          _card([
            _row(Icons.person, 'العميل', trip.clientName),
            _row(Icons.phone, 'الهاتف', trip.clientPhone),
          ]),
          SizedBox(height: 16.h),
          _card([
            _row(Icons.my_location, 'من', trip.from.address ?? _coord(trip.from),
                color: AppColors.success),
            _row(Icons.location_on, 'إلى', trip.to.address ?? _coord(trip.to),
                color: AppColors.primaryOrange),
            _row(Icons.route, 'المسافة',
                '${trip.distanceKm.toStringAsFixed(2)} كم'),
          ]),
          SizedBox(height: 16.h),
          _card([
            _row(Icons.payments, 'السعر', '${trip.price.toStringAsFixed(0)} ج.م',
                color: AppColors.primary),
            _row(trip.isPaid ? Icons.check_circle : Icons.pending,
                'الدفع', trip.isPaid ? 'مدفوعة' : 'غير مدفوعة',
                color: trip.isPaid ? AppColors.success : AppColors.grey),
            _row(Icons.flag, 'الحالة', _statusAr(trip.status)),
          ]),
        ],
      ),
    );
  }

  String _coord(TripPlace p) =>
      '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}';

  String _statusAr(String s) => switch (s) {
        'Completed' => 'مكتملة',
        'Canceled' => 'ملغاة',
        'InProgress' => 'جارية',
        'Arrived' => 'وصل السائق',
        'Accepted' => 'مقبولة',
        _ => 'قيد الانتظار',
      };

  Widget _card(List<Widget> children) => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.darkGrey,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(children: children),
      );

  Widget _row(IconData icon, String label, String value,
      {Color color = AppColors.grey}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 20.r, color: color),
          SizedBox(width: 12.w),
          Text('$label:', style: AppStyle.hint),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(value,
                style: AppStyle.body, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
