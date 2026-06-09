import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../cubit/scooter_cubit.dart';

class ScooterView extends StatelessWidget {
  const ScooterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('بيانات السكوتر',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: BlocBuilder<ScooterCubit, ScooterState>(
        builder: (context, state) {
          if (state.status == ScooterStatus.loading ||
              state.status == ScooterStatus.initial) {
            return const Center(
                child: SpinKitThreeBounce(color: AppColors.primary, size: 32));
          }
          if (state.status == ScooterStatus.error) {
            return _Message(
              icon: Icons.error_outline,
              text: state.error ?? 'حدث خطأ',
              onRetry: () => context.read<ScooterCubit>().load(),
            );
          }
          final p = state.profile;
          if (p == null) {
            return const _Message(
                icon: Icons.two_wheeler, text: 'لا توجد بيانات');
          }
          return RefreshIndicator(
            onRefresh: () => context.read<ScooterCubit>().load(),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _ScooterHeader(type: p.scooterTypeAr),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.darkGrey,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      _row(Icons.two_wheeler, 'نوع السكوتر', p.scooterTypeAr),
                      _divider(),
                      _row(Icons.confirmation_number_outlined, 'لوحة السكوتر',
                          p.scooterLicense?.isNotEmpty == true
                              ? p.scooterLicense!
                              : 'غير محدد'),
                      _divider(),
                      _row(Icons.badge_outlined, 'رخصة القيادة',
                          p.license?.isNotEmpty == true ? p.license! : 'غير محدد'),
                      _divider(),
                      _row(Icons.route, 'عدد الرحلات', '${p.tripCount}'),
                      _divider(),
                      _row(Icons.star, 'التقييم',
                          p.rate != null ? p.rate!.toStringAsFixed(1) : '—'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _divider() => const Divider(color: AppColors.grey, height: 1);

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22.r),
          SizedBox(width: 14.w),
          Text(label, style: AppStyle.hint),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: AppStyle.body,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _ScooterHeader extends StatelessWidget {
  const _ScooterHeader({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 26.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Icon(Icons.two_wheeler, size: 56.r, color: AppColors.primary),
          SizedBox(height: 8.h),
          Text(type, style: AppStyle.title.copyWith(color: AppColors.primary)),
        ],
      ),
    );
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
                  style: AppStyle.body.copyWith(color: AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }
}
