import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../data/models/rating_model.dart';
import '../cubit/ratings_cubit.dart';

class RatingsView extends StatelessWidget {
  const RatingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تقييماتي',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: BlocBuilder<RatingsCubit, RatingsState>(
        builder: (context, state) {
          if (state.status == RatingsStatus.loading ||
              state.status == RatingsStatus.initial) {
            return const Center(
                child: SpinKitThreeBounce(color: AppColors.primary, size: 32));
          }
          if (state.status == RatingsStatus.error) {
            return _Message(
              icon: Icons.error_outline,
              text: state.error ?? 'حدث خطأ',
              onRetry: () => context.read<RatingsCubit>().load(),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<RatingsCubit>().load(),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _Summary(average: state.average, count: state.count),
                SizedBox(height: 20.h),
                if (state.count == 0)
                  Padding(
                    padding: EdgeInsets.only(top: 60.h),
                    child: const _Message(
                        icon: Icons.star_border, text: 'لا توجد تقييمات بعد'),
                  )
                else ...[
                  Text('التعليقات', style: AppStyle.body),
                  SizedBox(height: 12.h),
                  if (state.withComments.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      child: Text('لا توجد تعليقات مكتوبة',
                          style: AppStyle.hint, textAlign: TextAlign.center),
                    )
                  else
                    ...state.withComments.map((r) => _CommentCard(rating: r)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.average, required this.count});
  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Text(average.toStringAsFixed(1),
              style: AppStyle.title.copyWith(
                  color: AppColors.primary, fontSize: 40.sp)),
          SizedBox(height: 8.h),
          _Stars(value: average),
          SizedBox(height: 8.h),
          Text('$count تقييم', style: AppStyle.hint),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < value.round();
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: AppColors.primary,
          size: 26.r,
        );
      }),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.rating});
  final RatingModel rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating.score ? Icons.star : Icons.star_border,
                color: AppColors.primary,
                size: 18.r,
              ),
            ),
          ),
          if ((rating.comment ?? '').isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(rating.comment!, style: AppStyle.body),
          ],
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
