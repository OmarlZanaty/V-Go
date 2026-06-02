import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/di.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/user_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';
import '../../../../core/utils/widgets/logout_button.dart';
import '../../../auth/presentation/logic/cubit/auth_cubit.dart';

class AccountantOrDispatcherInfo extends StatelessWidget {
  const AccountantOrDispatcherInfo({required this.user, super.key});
  final UserModel user;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 12,
      leading: CustomAvatar(
        imageUrl: user.profilePicture,
        radius: 28,
      ),

      title: Text(
        user.name,
        style: AppStyle.styleMedium18.copyWith(color: AppColors.white),
      ),
      subtitle: Text(
        user.email ?? user.phoneNumber ?? '',
        style: AppStyle.styleRegular14.copyWith(color: AppColors.white),
      ),
      trailing: BlocProvider(
        create: (context) => AuthCubit(getIt()),
        child: const LogoutButton(isIcon: true),
      ),
    );
  }
}
