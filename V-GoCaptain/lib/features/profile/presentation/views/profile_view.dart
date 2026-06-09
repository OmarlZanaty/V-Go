import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/cache/cache_helper.dart';
import '../../../../core/helpers/navigation_handler.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../home/presentation/logic/cubit/captain_home_cubit.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await context.read<CaptainHomeCubit>().goOffline();
    } catch (_) {}
    await CacheHelper.clearAllSecuredData();
    await CacheHelper.removeData(key: AppConstants.role);
    await CacheHelper.removeData(key: AppConstants.userName);
    await CacheHelper.removeData(key: AppConstants.profileImage);
    AppConstants.kToken = '';
    AppConstants.kUserId = '';
    AppConstants.kRole = '';
    AppConstants.kUserName = '';
    AppConstants.kProfileImage = '';
    NavigationHandler.instance.goToLoginView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('حسابي',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _header(),
          SizedBox(height: 24.h),
          _tile(Icons.lock_outline, 'تغيير كلمة المرور',
              () => NavigationHandler.navigatorKey.currentState
                  ?.pushNamed(Routes.changePasswordViewRoute)),
          _tile(Icons.two_wheeler_outlined, 'بيانات السكوتر',
              () => NavigationHandler.navigatorKey.currentState
                  ?.pushNamed(Routes.scooterViewRoute)),
          _tile(Icons.star_outline, 'تقييماتي',
              () => NavigationHandler.navigatorKey.currentState
                  ?.pushNamed(Routes.ratingsViewRoute)),
          _tile(Icons.settings_outlined, 'الإعدادات',
              () => NavigationHandler.navigatorKey.currentState
                  ?.pushNamed(Routes.settingsViewRoute)),
          _tile(Icons.support_agent_outlined, 'الدعم الفني',
              () => NavigationHandler.navigatorKey.currentState
                  ?.pushNamed(Routes.supportViewRoute)),
          _tile(Icons.privacy_tip_outlined, 'الشروط والخصوصية',
              () => NavigationHandler.navigatorKey.currentState
                  ?.pushNamed(Routes.termsViewRoute)),
          SizedBox(height: 8.h),
          _tile(Icons.logout, 'تسجيل الخروج', () => _logout(context),
              color: AppColors.danger),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32.r,
            backgroundColor: AppColors.primary,
            backgroundImage: AppConstants.kProfileImage.isNotEmpty
                ? NetworkImage(AppConstants.kProfileImage)
                : null,
            child: AppConstants.kProfileImage.isEmpty
                ? Icon(Icons.person, color: AppColors.black, size: 34.r)
                : null,
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.kUserName.isNotEmpty
                      ? AppConstants.kUserName
                      : 'كابتن V-Go',
                  style: AppStyle.title,
                ),
                SizedBox(height: 4.h),
                Text('سائق', style: AppStyle.hint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback? onTap,
      {Color color = AppColors.white}) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: AppStyle.body.copyWith(color: color)),
        trailing: onTap == null
            ? Text('قريباً', style: AppStyle.hint)
            : Icon(Icons.chevron_left, color: AppColors.grey, size: 22.r),
        onTap: onTap,
      ),
    );
  }
}
