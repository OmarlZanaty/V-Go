import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../../../trips/presentation/logic/trip_cubit/trip_cubit.dart';
import 'dashboard_interactive_container.dart';

class ChangeDriverCommissionSection extends StatelessWidget {
  const ChangeDriverCommissionSection({
    required this.currentPercentage,
    super.key,
  });
  final String currentPercentage;
  @override
  Widget build(BuildContext context) {
    return BlocListener<TripCubit, TripState>(
      listenWhen: (previous, current) => _listenWhen(current),
      listener: (context, state) {
        if (state.status.isChangeDriverCommissionSuccess) {
          context.pop();
          successToast(context, 'عملية ناجحة', state.successMessage);
        } else if (state.status.isChangeDriverCommissionFailure) {
          context.pop();
          errorToast(context, 'عملية فاشلة', state.errorMessage);
        } else if (state.status.isChangeDriverCommissionLoading) {
          loadingDialog(context);
        }
      },
      child: DashboardInteractiveContainer(
        title: 'العمولة',
        icon: HugeIcons.strokeRoundedMoneyAdd02,
        onTap: () {
          changeDriverCommissionDialog(
            context: context,
            currentPercentage: currentPercentage,
          );
        },
      ),
    );
  }

  bool _listenWhen(TripState state) {
    return state.status.isChangeDriverCommissionFailure ||
        state.status.isChangeDriverCommissionSuccess ||
        state.status.isChangeDriverCommissionLoading;
  }

  void changeDriverCommissionDialog({
    required BuildContext context,
    required String currentPercentage,
  }) {
    final TextEditingController commissionController = TextEditingController(
      text: currentPercentage,
    );

    AwesomeDialog(
      context: context,
      animType: AnimType.rightSlide,
      headerAnimationLoop: false,
      dialogType: DialogType.noHeader,
      title: 'تغيير العمولة',
      desc: 'ادخل العمولة الجديدة',
      dialogBackgroundColor: AppColors.darkGrey,
      body: Padding(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 0),
        child: CustomTextField(
          labelText: 'العمولة (0 - 100)',
          controller: commissionController,
          keyboardType: TextInputType.number,
        ),
      ),
      btnOkOnPress: () {
        if (commissionController.text.trim().isEmpty) return;
        context.read<TripCubit>().changeDriverCommission(
          percentage: double.parse(commissionController.text),
        );
      },
      btnCancelOnPress: () {},
      btnOkText: 'تغيير',
      btnCancelText: 'إلغاء',
      reverseBtnOrder: true,
      buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
    ).show();
  }
}
