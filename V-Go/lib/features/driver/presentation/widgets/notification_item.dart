import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/convert_time.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/notification_model.dart';

class NotificationItem extends StatelessWidget {
  const NotificationItem({required this.notification, super.key});
  final NotificationModel notification;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, right: 10),
            padding: const EdgeInsets.only(
              top: 4,
              left: 14,
              right: 14,
              bottom: 3,
            ),
            decoration: const BoxDecoration(
              color: AppColors.lightWhite,
              borderRadius: BorderRadius.all(Radius.circular(50)),
            ),
            child: Text(
              notification.title ?? '',
              style: AppStyle.styleMedium12.copyWith(color: AppColors.white),
            ),
          ),
          verticalSpace(8),
          ListTile(
            horizontalTitleGap: 14,
            isThreeLine: true,
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.19),
              radius: 20,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedNotification02,
                color: AppColors.primary,
                size: 21,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.body ?? '',
                  style: AppStyle.styleMedium14.copyWith(
                    color: AppColors.white,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    convertTime(notification.createdAt),
                    style: AppStyle.styleMedium12.copyWith(
                      color: AppColors.white,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
