import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/cache/cache_helper.dart';
import '../../../../core/di/di.dart';
import '../../../../core/helpers/navigation_handler.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../widgets/emergency_alert_item.dart';
import '../widgets/settings_item.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  void _openPdf(BuildContext context, String asset, String title) {
    Navigator.of(context).pushNamed(
      Routes.pdfViewRoute,
      arguments: {'assetPath': asset, 'title': title},
    );
  }

  Future<void> _logout() async {
    // Best-effort: drop the realtime connection (marks the driver offline).
    try {
      await getIt<RealtimeService>().disconnect();
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
        title: Text('الإعدادات',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          // ---------- General ----------
          const SettingsSectionHeader(title: 'الإعدادات العامة'),
          SettingsItem(
            title: 'الإشعارات',
            icon: Icons.notifications_none_rounded,
            onTap: () =>
                AppSettings.openAppSettings(type: AppSettingsType.notification),
          ),
          SettingsItem(
            title: 'الموقع الجغرافي',
            icon: Icons.location_on_outlined,
            onTap: () =>
                AppSettings.openAppSettings(type: AppSettingsType.location),
          ),

          // ---------- Policies & support ----------
          const SettingsSectionHeader(title: 'السياسات والدعم'),
          SettingsItem(
            title: 'سياسة الخصوصية',
            icon: Icons.privacy_tip_outlined,
            onTap: () =>
                _openPdf(context, 'assets/files/policy.pdf', 'سياسة الخصوصية'),
          ),
          SettingsItem(
            title: 'سياسة التسعير',
            icon: Icons.sell_outlined,
            onTap: () => _openPdf(
                context, 'assets/files/pricingPolicy.pdf', 'سياسة التسعير'),
          ),
          SettingsItem(
            title: 'سياسة الإسترجاع',
            icon: Icons.replay_outlined,
            onTap: () => _openPdf(
                context, 'assets/files/refundPolicy.pdf', 'سياسة الإسترجاع'),
          ),
          SettingsItem(
            title: 'تواصل معنا',
            icon: Icons.mail_outline_rounded,
            onTap: () =>
                _openPdf(context, 'assets/files/contactUs.pdf', 'تواصل معنا'),
          ),
          SettingsItem(
            title: 'الدعم الفني',
            icon: Icons.support_agent_outlined,
            onTap: () => Navigator.of(context).pushNamed(Routes.supportViewRoute),
          ),

          // ---------- Account ----------
          const SettingsSectionHeader(title: 'الحساب'),
          SettingsItem(
            title: 'تغيير كلمة المرور',
            icon: Icons.lock_outline_rounded,
            onTap: () => Navigator.of(context)
                .pushNamed(Routes.changePasswordViewRoute),
          ),
          SettingsItem(
            title: 'إصدار التطبيق',
            icon: Icons.info_outline_rounded,
            onTap: null,
            trailing: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) => Text(
                snap.hasData ? snap.data!.version : '...',
                style: AppStyle.hint,
              ),
            ),
          ),
          SettingsItem(
            title: 'تسجيل الخروج',
            icon: Icons.logout_rounded,
            color: AppColors.danger,
            trailing: const SizedBox.shrink(),
            onTap: _logout,
          ),

          // ---------- Captain-only ----------
          const SettingsSectionHeader(title: 'الطوارئ'),
          const EmergencyAlertItem(),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
