import 'package:flutter/material.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/user_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';

class DriverInfo extends StatelessWidget {
  const DriverInfo({required this.user, super.key});
  final UserModel user;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        horizontalTitleGap: 10,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        leading: CustomAvatar(imageUrl: user.profilePicture, radius: 28),
        title: Text(
          user.name,
          style: AppStyle.styleMedium18.copyWith(color: Colors.white),
        ),
        subtitle: Text(
          user.email ?? '',
          style: AppStyle.styleMedium14.copyWith(color: AppColors.lightGrey),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, color: Colors.amber),
            verticalSpace(2),
            Text(
              user.rate!.toStringAsFixed(1),
              style: AppStyle.styleMedium16.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
