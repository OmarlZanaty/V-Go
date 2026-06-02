import 'package:animate_do/animate_do.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/di/di.dart';
import '../../core/helpers/extensions.dart';
import '../../core/routing/routes.dart';
import '../../core/theming/app_colors.dart';
import '../../core/theming/app_style.dart';
import '../../core/utils/widgets/custom_app_bar.dart';
import '../auth/presentation/logic/cubit/auth_cubit.dart';
import 'emergecy_settings_item.dart';
import 'logout_settings_item.dart';
import 'settings_item.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, this.isDriver = false});
  final bool isDriver;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'الاعدادات'),
      body: SingleChildScrollView(
        child: SlideInUp(
          from: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              spacing: 8,
              children: [
                const _SettingsHeader(title: 'الإعدادات العامة'),
                SettingsItem(
                  title: 'الاشعارات',
                  icon: HugeIcons.strokeRoundedNotification03,
                  onTap: () {
                    AppSettings.openAppSettings(
                      type: AppSettingsType.notification,
                    );
                  },
                ),
                SettingsItem(
                  title: 'الموقع الجغرافي',
                  icon: HugeIcons.strokeRoundedLocation03,
                  onTap: () {
                    AppSettings.openAppSettings(type: AppSettingsType.location);
                  },
                ),
                const _SettingsHeader(title: 'السياسات والدعم'),
                SettingsItem(
                  title: 'سياسة الخصوصية',
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  onTap: () {
                    context.pushNamed(Routes.pdfViewRoute);
                  },
                ),
                SettingsItem(
                  title: 'سياسة التسعير',
                  icon: HugeIcons.strokeRoundedTag01,
                  onTap: () {
                    context.pushNamed(
                      Routes.pdfViewRoute,
                      arguments: {
                        'assetPath': 'assets/files/pricingPolicy.pdf',
                        'title': 'سياسة التسعير',
                      },
                    );
                  },
                ),
                SettingsItem(
                  title: 'سياسة الإسترجاع',
                  icon: HugeIcons.strokeRoundedArrowTurnBackward,
                  onTap: () {
                    context.pushNamed(
                      Routes.pdfViewRoute,
                      arguments: {
                        'assetPath': 'assets/files/refundPolicy.pdf',
                        'title': 'سياسة الإسترجاع',
                      },
                    );
                  },
                ),
                SettingsItem(
                  title: 'تواصل معنا',
                  icon: HugeIcons.strokeRoundedMail01,
                  onTap: () {
                    context.pushNamed(
                      Routes.pdfViewRoute,
                      arguments: {
                        'assetPath': 'assets/files/contactUs.pdf',
                        'title': 'تواصل معنا',
                      },
                    );
                  },
                ),
                if (!isDriver) ...[
                  SettingsItem(
                    title: 'خدمة العملاء',
                    icon: HugeIcons.strokeRoundedHeadphones,
                    onTap: () {
                      context.pushNamed(
                        Routes.chatViewRoute,
                        arguments: {
                          'isClient': true,
                          'dispatcherChatModel': null,
                        },
                      );
                    },
                  ),
                ],
                const _SettingsHeader(title: 'الحساب'),
                SettingsItem(
                  title: 'تغيير كلمة المرور',
                  icon: HugeIcons.strokeRoundedSquareLock02,
                  onTap: () {
                    context.pushNamed(Routes.changePasswordViewRoute);
                  },
                ),
                BlocProvider(
                  create: (context) => AuthCubit(getIt()),
                  child: const LogOutSettingsItem(),
                ),
                if (isDriver) ...[
                  const _SettingsHeader(title: 'الطوارئ'),
                  const EmergecySettingsItem(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8, right: 8),
        child: Text(
          title,
          style: AppStyle.styleBold20.copyWith(
            color: AppColors.primary,
            fontSize: 16.sp,
          ),
        ),
      ),
    );
  }
}
