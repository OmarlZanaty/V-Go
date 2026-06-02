import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../trips/data/models/trip_model.dart';
import '../../../trips/presentation/cubit/trips_cubit.dart';

class EarningsView extends StatelessWidget {
  const EarningsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الأرباح',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: BlocBuilder<TripsCubit, TripsState>(
        builder: (context, state) {
          if (state.status == TripsStatus.loading) {
            return const Center(
                child: SpinKitThreeBounce(color: AppColors.primary, size: 32));
          }
          final paidTrips = state.paid;
          return RefreshIndicator(
            onRefresh: () => context.read<TripsCubit>().load(),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _summary(state),
                SizedBox(height: 20.h),
                Text('المعاملات', style: AppStyle.title),
                SizedBox(height: 12.h),
                if (paidTrips.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Center(
                        child: Text('لا توجد معاملات بعد', style: AppStyle.hint)),
                  )
                else
                  ...paidTrips.map((t) => _transaction(t)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summary(TripsState state) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Text('${state.totalEarnings.toStringAsFixed(0)} ج.م',
              style: AppStyle.heading.copyWith(color: AppColors.primary)),
          SizedBox(height: 4.h),
          Text('إجمالي الأرباح', style: AppStyle.hint),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                  child: _stat('اليوم',
                      '${state.todayEarnings.toStringAsFixed(0)} ج.م')),
              Container(width: 1, height: 36.h, color: AppColors.grey),
              Expanded(
                  child: _stat('رحلات مكتملة', '${state.completedCount}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value, style: AppStyle.title),
          SizedBox(height: 4.h),
          Text(label, style: AppStyle.hint),
        ],
      );

  Widget _transaction(TripModel t) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: AppColors.success.withValues(alpha: 0.18),
            child: Icon(Icons.arrow_downward,
                color: AppColors.success, size: 20.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.clientName, style: AppStyle.body),
                Text(_date(t.createdAt), style: AppStyle.hint),
              ],
            ),
          ),
          Text('+${t.price.toStringAsFixed(0)} ج.م',
              style: AppStyle.body.copyWith(color: AppColors.success)),
        ],
      ),
    );
  }

  String _date(DateTime? d) => d == null
      ? ''
      : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}
