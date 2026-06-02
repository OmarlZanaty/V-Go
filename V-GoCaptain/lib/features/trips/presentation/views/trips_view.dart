import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../data/models/trip_model.dart';
import '../cubit/trips_cubit.dart';
import 'trip_details_view.dart';

class TripsView extends StatelessWidget {
  const TripsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('رحلاتي',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: BlocBuilder<TripsCubit, TripsState>(
        builder: (context, state) {
          if (state.status == TripsStatus.loading) {
            return const Center(
                child: SpinKitThreeBounce(color: AppColors.primary, size: 32));
          }
          if (state.status == TripsStatus.error) {
            return _Message(
              icon: Icons.error_outline,
              text: state.error ?? 'حدث خطأ',
              onRetry: () => context.read<TripsCubit>().load(),
            );
          }
          if (state.trips.isEmpty) {
            return const _Message(
                icon: Icons.history, text: 'لا توجد رحلات بعد');
          }
          return RefreshIndicator(
            onRefresh: () => context.read<TripsCubit>().load(),
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: state.trips.length,
              separatorBuilder: (_, _) => SizedBox(height: 12.h),
              itemBuilder: (_, i) => _TripCard(trip: state.trips[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailsView(trip: trip)),
      ),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.darkGrey,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.clientName, style: AppStyle.body),
                  SizedBox(height: 4.h),
                  Text(_dateText(trip.createdAt), style: AppStyle.hint),
                  SizedBox(height: 8.h),
                  Row(children: [
                    Icon(Icons.route, size: 16.r, color: AppColors.grey),
                    SizedBox(width: 4.w),
                    Text('${trip.distanceKm.toStringAsFixed(1)} كم',
                        style: AppStyle.hint),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${trip.price.toStringAsFixed(0)} ج.م',
                    style: AppStyle.title.copyWith(color: AppColors.primary)),
                SizedBox(height: 8.h),
                _StatusChip(status: trip.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateText(DateTime? d) {
    if (d == null) return '';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _info(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(label, style: AppStyle.hint.copyWith(color: color)),
    );
  }

  (String, Color) _info(String s) {
    switch (s) {
      case 'Completed':
        return ('مكتملة', AppColors.success);
      case 'Canceled':
        return ('ملغاة', AppColors.danger);
      case 'InProgress':
        return ('جارية', AppColors.primaryOrange);
      case 'Arrived':
        return ('وصل', AppColors.primary);
      case 'Accepted':
        return ('مقبولة', AppColors.primary);
      default:
        return ('قيد الانتظار', AppColors.grey);
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64.r, color: AppColors.grey),
          SizedBox(height: 12.h),
          Text(text, style: AppStyle.hint),
          if (onRetry != null) ...[
            SizedBox(height: 12.h),
            TextButton(
                onPressed: onRetry,
                child: Text('إعادة المحاولة',
                    style: AppStyle.body.copyWith(color: AppColors.primary))),
          ],
        ],
      ),
    );
  }
}
