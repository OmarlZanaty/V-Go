import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../trips/data/models/trip_model.dart';
import '../../../trips/presentation/cubit/trips_cubit.dart';
import '../../../trips/presentation/views/trip_details_view.dart';

enum EarningsRange { today, week, month, all }

extension EarningsRangeX on EarningsRange {
  String get label => switch (this) {
        EarningsRange.today => 'اليوم',
        EarningsRange.week => 'الأسبوع',
        EarningsRange.month => 'الشهر',
        EarningsRange.all => 'الكل',
      };

  /// Inclusive check: does [d] fall within this range relative to now?
  bool contains(DateTime? d) {
    if (d == null) return this == EarningsRange.all;
    final now = DateTime.now();
    switch (this) {
      case EarningsRange.today:
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case EarningsRange.week:
        final weekAgo =
            DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        return !d.isBefore(weekAgo);
      case EarningsRange.month:
        return d.year == now.year && d.month == now.month;
      case EarningsRange.all:
        return true;
    }
  }
}

class EarningsView extends StatefulWidget {
  const EarningsView({super.key});

  @override
  State<EarningsView> createState() => _EarningsViewState();
}

class _EarningsViewState extends State<EarningsView> {
  EarningsRange _range = EarningsRange.week;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('الأرباح',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: BlocBuilder<TripsCubit, TripsState>(
        builder: (context, state) {
          if (state.status == TripsStatus.loading && state.trips.isEmpty) {
            return const Center(
                child: SpinKitThreeBounce(color: AppColors.primary, size: 32));
          }

          final completed = state.trips
              .where((t) => t.isCompleted && _range.contains(t.createdAt))
              .toList()
            ..sort((a, b) => (b.createdAt ?? DateTime(0))
                .compareTo(a.createdAt ?? DateTime(0)));
          final paid = completed.where((t) => t.isPaid).toList();
          final pending = completed.where((t) => !t.isPaid).toList();

          final earnings = paid.fold<double>(0, (s, t) => s + t.price);
          final pendingAmount = pending.fold<double>(0, (s, t) => s + t.price);
          final distance = completed.fold<double>(0, (s, t) => s + t.distanceKm);
          final avg = paid.isEmpty ? 0.0 : earnings / paid.length;

          return RefreshIndicator(
            onRefresh: () => context.read<TripsCubit>().load(),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _RangeSelector(
                  value: _range,
                  onChanged: (r) => setState(() => _range = r),
                ),
                SizedBox(height: 16.h),
                _HeroCard(
                  earnings: earnings,
                  trips: completed.length,
                  distance: distance,
                  avg: avg,
                  rangeLabel: _range.label,
                ),
                if (pending.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  _PendingBanner(count: pending.length, amount: pendingAmount),
                ],
                SizedBox(height: 20.h),
                _WeeklyChart(trips: state.trips),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Text('المعاملات', style: AppStyle.title),
                    const Spacer(),
                    Text('${completed.length} رحلة', style: AppStyle.hint),
                  ],
                ),
                SizedBox(height: 12.h),
                if (completed.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Center(
                        child: Text('لا توجد معاملات في هذه الفترة',
                            style: AppStyle.hint)),
                  )
                else
                  ...completed.map((t) => _TransactionCard(trip: t)),
                SizedBox(height: 20.h),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});
  final EarningsRange value;
  final ValueChanged<EarningsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: EarningsRange.values.map((r) {
          final selected = r == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  r.label,
                  textAlign: TextAlign.center,
                  style: AppStyle.body.copyWith(
                    color: selected ? AppColors.black : AppColors.grey,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.earnings,
    required this.trips,
    required this.distance,
    required this.avg,
    required this.rangeLabel,
  });
  final double earnings;
  final int trips;
  final double distance;
  final double avg;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Text('أرباح $rangeLabel', style: AppStyle.hint),
          SizedBox(height: 6.h),
          Text('${earnings.toStringAsFixed(0)} ج.م',
              style: AppStyle.heading.copyWith(color: AppColors.primary)),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(child: _stat(Icons.route, 'رحلات', '$trips')),
              _sep(),
              Expanded(
                  child: _stat(Icons.straighten, 'المسافة',
                      '${distance.toStringAsFixed(1)} كم')),
              _sep(),
              Expanded(
                  child: _stat(Icons.payments_outlined, 'متوسط الرحلة',
                      '${avg.toStringAsFixed(0)} ج.م')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sep() => Container(width: 1, height: 40.h, color: AppColors.grey);

  Widget _stat(IconData icon, String label, String value) => Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20.r),
          SizedBox(height: 6.h),
          Text(value, style: AppStyle.body),
          SizedBox(height: 2.h),
          Text(label, style: AppStyle.hint, textAlign: TextAlign.center),
        ],
      );
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.amount});
  final int count;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom,
              color: AppColors.primaryOrange, size: 22.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Text('$count رحلة بانتظار الدفع',
                style: AppStyle.body.copyWith(color: AppColors.primaryOrange)),
          ),
          Text('${amount.toStringAsFixed(0)} ج.م',
              style: AppStyle.body.copyWith(color: AppColors.primaryOrange)),
        ],
      ),
    );
  }
}

/// Simple dependency-free bar chart of the last 7 days' paid earnings.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.trips});
  final List<TripModel> trips;

  static const _weekdayShort = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];

  List<({DateTime day, double amount})> _days() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) {
      final day = start.subtract(Duration(days: 6 - i));
      final amount = trips
          .where((t) =>
              t.isCompleted &&
              t.isPaid &&
              t.createdAt != null &&
              t.createdAt!.year == day.year &&
              t.createdAt!.month == day.month &&
              t.createdAt!.day == day.day)
          .fold<double>(0, (s, t) => s + t.price);
      return (day: day, amount: amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = _days();
    final maxAmount =
        days.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);
    final today = DateTime.now();

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('أرباح آخر ٧ أيام', style: AppStyle.body),
          SizedBox(height: 16.h),
          SizedBox(
            height: 110.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((e) {
                final isToday = e.day.year == today.year &&
                    e.day.month == today.month &&
                    e.day.day == today.day;
                final ratio = maxAmount == 0 ? 0.0 : e.amount / maxAmount;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        e.amount == 0 ? '' : e.amount.toStringAsFixed(0),
                        style: AppStyle.hint.copyWith(fontSize: 9.sp),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        height: (8 + ratio * 60).h,
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(_weekdayShort[e.day.weekday - 1],
                          style: AppStyle.hint.copyWith(fontSize: 10.sp)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.trip});
  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final paid = trip.isPaid;
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailsView(trip: trip)),
      ),
      child: Container(
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
              backgroundColor: (paid ? AppColors.success : AppColors.primaryOrange)
                  .withValues(alpha: 0.18),
              child: Icon(
                paid ? Icons.check : Icons.hourglass_bottom,
                color: paid ? AppColors.success : AppColors.primaryOrange,
                size: 20.r,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.clientName,
                      style: AppStyle.body, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2.h),
                  Text(_dateTime(trip.createdAt), style: AppStyle.hint),
                  SizedBox(height: 2.h),
                  Text('${trip.distanceKm.toStringAsFixed(1)} كم',
                      style: AppStyle.hint),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  paid
                      ? '+${trip.price.toStringAsFixed(0)} ج.م'
                      : '${trip.price.toStringAsFixed(0)} ج.م',
                  style: AppStyle.body.copyWith(
                    color: paid ? AppColors.success : AppColors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(paid ? 'مدفوعة' : 'بانتظار الدفع',
                    style: AppStyle.hint.copyWith(
                      color: paid ? AppColors.success : AppColors.primaryOrange,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateTime(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }
}
