import 'package:flutter/material.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/user_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';

class UserListTileItem extends StatelessWidget {
  const UserListTileItem({
    required this.user,
    required this.onTap,
    super.key,
    this.contentPadding,
    this.showSubtitle = false,
    this.whiteBackground = false,
  });
  final UserModel user;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? contentPadding;
  final bool showSubtitle;
  final bool whiteBackground;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: ListTile(
        onTap: onTap,
        horizontalTitleGap: 14,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        leading: CustomAvatar(
          imageUrl: user.profilePicture,
          whiteBackground: whiteBackground,
        ),
        title: Text(
          user.name,
          style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
        ),
        subtitle: showSubtitle
            ? Text(user.phoneNumber ?? '', style: AppStyle.styleRegular14)
            : null,
      ),
    );
  }
}
