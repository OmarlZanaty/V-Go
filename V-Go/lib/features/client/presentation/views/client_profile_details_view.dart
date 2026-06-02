import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_refresh_indicator.dart';
import '../../../trips/presentation/widgets/client_trips_count_section.dart';
import '../widgets/client_info.dart';

class ClientProfileDetailsView extends StatelessWidget {
  const ClientProfileDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'بيانات المستخدم'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BlocBuilder<UserCubit, UserState>(
          builder: (context, state) {
            if (state.status.isGetUserDetailsSuccess) {
              return _clientProfileSuccess(state, context);
            } else if (state.status.isGetUserDetailsFailure) {
              return CustomRefreshIndicator(
                onRefresh: () async {
                  await context.read<UserCubit>().getUserDetails(
                    AppConstants.kUserId,
                  );
                },
                child: ListView(
                  children: [
                    SizedBox(
                      height: 0.8.sh,
                      child: CustomFailureWidget(text: state.errorMessage),
                    ),
                  ],
                ),
              );
            }
            return const CustomLoadingWidget();
          },
        ),
      ),
    );
  }

  CustomScrollView _clientProfileSuccess(
    UserState state,
    BuildContext context,
  ) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              verticalSpace(16),
              ClientInfo(user: state.userDetails!),
              verticalSpace(14),
              ClientTripsCountSection(
                tripCount: state.userDetails!.tripCount ?? 0,
                rating: state.userDetails?.rate?.toDouble() ?? 0.0,
              ),
              Expanded(child: verticalSpace(30)),
              SlideInUp(
                child: CustomButton(
                  text: 'تعديل الحساب',
                  height: 52,
                  onPressed: () async {
                    final result = await context.pushNamed(
                      Routes.updateUserViewRoute,
                      arguments: state.userDetails,
                    );
                    if (result != null && result == true && context.mounted) {
                      context.read<UserCubit>().getUserDetails(
                        state.userDetails!.id,
                      );
                    }
                  },
                ),
              ),
              verticalSpace(16),
            ],
          ),
        ),
      ],
    );
  }
}
