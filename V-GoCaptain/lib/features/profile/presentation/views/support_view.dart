import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../cubit/support_cubit.dart';

class SupportView extends StatefulWidget {
  const SupportView({super.key});

  @override
  State<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<SupportView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الدعم الفني',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: BlocConsumer<SupportCubit, SupportState>(
        listener: (context, state) {
          if (state.status == SupportStatus.success) {
            _controller.clear();
            FocusScope.of(context).unfocus();
            toastification.show(
              context: context,
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              title: Text('تم إرسال رسالتك، سنتواصل معك قريبًا',
                  style: AppStyle.body),
              autoCloseDuration: const Duration(seconds: 4),
              alignment: Alignment.bottomCenter,
            );
          } else if (state.status == SupportStatus.error) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              title: Text(state.error ?? 'تعذّر إرسال الرسالة',
                  style: AppStyle.body),
              autoCloseDuration: const Duration(seconds: 4),
              alignment: Alignment.bottomCenter,
            );
          }
        },
        builder: (context, state) {
          final sending = state.status == SupportStatus.submitting;
          return ListView(
            padding: EdgeInsets.all(20.w),
            children: [
              Row(
                children: [
                  Icon(Icons.support_agent,
                      color: AppColors.primary, size: 28.r),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'صف مشكلتك أو استفسارك وسيتواصل معك فريق الدعم.',
                      style: AppStyle.hint,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.darkGrey,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: TextField(
                  controller: _controller,
                  maxLines: 6,
                  minLines: 5,
                  maxLength: 1000,
                  style: AppStyle.body,
                  enabled: !sending,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'اكتب رسالتك هنا...',
                    hintStyle: AppStyle.hint,
                    counterStyle: AppStyle.hint,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                height: 52.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  onPressed: sending
                      ? null
                      : () =>
                          context.read<SupportCubit>().submit(_controller.text),
                  child: sending
                      ? const CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.black)
                      : Text('إرسال', style: AppStyle.button),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
