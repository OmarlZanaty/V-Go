import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/user_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';

class ClientInfo extends StatelessWidget {
  const ClientInfo({required this.user, super.key});
  final UserModel user;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SlideInDown(
          from: 200,
          delay: const Duration(milliseconds: 150),
          child: Column(
            children: [
              CustomAvatar(
                imageUrl: user.profilePicture,
                radius: 45,
                showOutlineBorder: true,
              ),
              verticalSpace(12),
              Text(
                user.name,
                style: AppStyle.styleBold20.copyWith(color: AppColors.white),
              ),
              verticalSpace(8),
              Text(
                user.email ?? '',
                style: AppStyle.styleRegular16.copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),

        verticalSpace(16),
        SlideInDown(
          from: 200,
          child: Container(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 6,
              left: 10,
              right: 14,
            ),
            decoration: const BoxDecoration(
              color: AppColors.lightWhite,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'رقم الهاتف',
                      style: AppStyle.styleMedium14.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    const CircleAvatar(
                      backgroundColor: AppColors.lightWhite,
                      foregroundColor: AppColors.primary,
                      child: Icon(HugeIcons.strokeRoundedCall),
                    ),
                  ],
                ),
                verticalSpace(4),
                Text(
                  user.phoneNumber ?? '',
                  style: AppStyle.styleBold24.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
