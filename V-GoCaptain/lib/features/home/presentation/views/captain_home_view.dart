import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/cache/cache_helper.dart';
import '../../../../core/helpers/navigation_handler.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../logic/cubit/captain_home_cubit.dart';
import '../widgets/active_trip_panel.dart';
import '../widgets/incoming_trip_card.dart';

class CaptainHomeView extends StatelessWidget {
  const CaptainHomeView({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<CaptainHomeCubit>().goOffline();
    await CacheHelper.clearAllSecuredData();
    await CacheHelper.removeData(key: AppConstants.role);
    AppConstants.kToken = '';
    AppConstants.kUserId = '';
    AppConstants.kRole = '';
    NavigationHandler.instance.goToLoginView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'V-Go Captain',
          style: AppStyle.title.copyWith(color: AppColors.black),
        ),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout, color: AppColors.black),
          ),
        ],
      ),
      body: BlocConsumer<CaptainHomeCubit, CaptainHomeState>(
        listenWhen: (prev, curr) => curr.error != null && prev.error != curr.error,
        listener: (context, state) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            title: Text(state.error!, style: AppStyle.body),
            autoCloseDuration: const Duration(seconds: 4),
            alignment: Alignment.bottomCenter,
          );
        },
        builder: (context, state) {
          return Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusCard(state: state),
                SizedBox(height: 20.h),
                Expanded(child: _body(context, state)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, CaptainHomeState state) {
    if (state.hasActiveTrip) {
      return ActiveTripPanel(state: state);
    }
    if (state.offer != null) {
      return IncomingTripCard(offer: state.offer!, isBusy: state.isBusy);
    }
    return _Idle(state: state);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});
  final CaptainHomeState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CaptainHomeCubit>();
    final connecting = state.connection == CaptainConnection.connecting;
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          Container(
            width: 14.r,
            height: 14.r,
            decoration: BoxDecoration(
              color: state.isOnline ? AppColors.success : AppColors.grey,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              connecting
                  ? 'جارٍ الاتصال...'
                  : state.isOnline
                      ? 'أنت متاح لاستقبال الرحلات'
                      : 'أنت غير متصل',
              style: AppStyle.body,
            ),
          ),
          if (connecting)
            SizedBox(
              width: 24.r,
              height: 24.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            Switch(
              value: state.isOnline,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => v ? cubit.goOnline() : cubit.goOffline(),
            ),
        ],
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.state});
  final CaptainHomeState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            state.isOnline ? Icons.search : Icons.nightlight_round,
            size: 72.r,
            color: AppColors.grey,
          ),
          SizedBox(height: 16.h),
          Text(
            state.isOnline
                ? 'جارٍ البحث عن رحلات قريبة...'
                : 'فعّل الاتصال لبدء استقبال الرحلات',
            textAlign: TextAlign.center,
            style: AppStyle.hint,
          ),
        ],
      ),
    );
  }
}
