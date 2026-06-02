import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/cache/cache_helper.dart';
import '../../../../core/helpers/navigation_handler.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';

/// Driver home shell. Online/offline toggle is wired locally; trip-matching,
/// map and live tracking are the next features to build on top of this.
class CaptainHomeView extends StatefulWidget {
  const CaptainHomeView({super.key});

  @override
  State<CaptainHomeView> createState() => _CaptainHomeViewState();
}

class _CaptainHomeViewState extends State<CaptainHomeView> {
  CaptainStatus _status = CaptainStatus.offline;

  bool get _isOnline => _status != CaptainStatus.offline;

  void _toggleOnline(bool value) {
    setState(() {
      _status = value ? CaptainStatus.online : CaptainStatus.offline;
    });
    // TODO: connect to driverHub (SignalR) and start location updates when online.
  }

  Future<void> _logout() async {
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
        title: Text('V-Go Captain', style: AppStyle.title.copyWith(
          color: AppColors.black,
        )),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.black),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusCard(),
            SizedBox(height: 24.h),
            Expanded(child: _tripsPlaceholder()),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
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
              color: _isOnline ? AppColors.success : AppColors.grey,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              _isOnline ? 'أنت متاح لاستقبال الرحلات' : 'أنت غير متصل',
              style: AppStyle.body,
            ),
          ),
          Switch(
            value: _isOnline,
            activeThumbColor: AppColors.primary,
            onChanged: _toggleOnline,
          ),
        ],
      ),
    );
  }

  Widget _tripsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isOnline ? Icons.search : Icons.nightlight_round,
            size: 72.r,
            color: AppColors.grey,
          ),
          SizedBox(height: 16.h),
          Text(
            _isOnline
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
