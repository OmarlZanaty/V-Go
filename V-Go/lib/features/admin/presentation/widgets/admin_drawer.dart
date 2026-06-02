import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/di/di.dart';
import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/logout_button.dart';
import '../../../auth/presentation/logic/cubit/auth_cubit.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.darkGrey,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: BlocBuilder<UserCubit, UserState>(
              builder: (context, state) {
                if (state.status.isGetUserDetailsSuccess) {
                  return Column(
                    children: [
                      verticalSpace(60),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        backgroundImage:
                            state.userDetails!.profilePicture.isNullOrEmpty()
                            ? null
                            : CachedNetworkImageProvider(
                                state.userDetails!.profilePicture!,
                              ),
                        child: state.userDetails!.profilePicture.isNullOrEmpty()
                            ? const HugeIcon(
                                icon: HugeIcons.strokeRoundedUser,
                                color: AppColors.primary,
                                size: 32,
                              )
                            : null,
                      ),
                      verticalSpace(20),
                      Text(
                        state.userDetails!.name,
                        style: AppStyle.styleBold20.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      verticalSpace(4),
                      Text(
                        state.userDetails!.email ?? '',
                        style: AppStyle.styleRegular14,
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: BlocProvider(
                          create: (context) => AuthCubit(getIt()),
                          child: const LogoutButton(),
                        ),
                      ),
                      verticalSpace(14),
                    ],
                  );
                } else if (state.status.isGetUserDetailsFailure) {
                  return CustomFailureWidget(text: state.errorMessage);
                }
                return const CustomLoadingWidget();
              },
            ),
          ),
        ],
      ),
    );
  }
}
