import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../../../trips/presentation/logic/trip_cubit/trip_cubit.dart';

void changeKiloMetrePriceDialog({
  required BuildContext context,
  required String currentPrice,
}) {
  final TextEditingController priceController = TextEditingController(
    text: currentPrice,
  );

  AwesomeDialog(
    context: context,
    animType: AnimType.rightSlide,
    headerAnimationLoop: false,
    dialogType: DialogType.noHeader,
    title: 'تغيير سعر الكيلو متر',
    desc: 'ادخل سعر الكيلو متر الجديد',
    dialogBackgroundColor: AppColors.darkGrey,
    body: Padding(
      padding: const EdgeInsets.all(16.0).copyWith(bottom: 0),
      child: CustomTextField(
        labelText: 'سعر الكيلو متر',
        controller: priceController,
        keyboardType: TextInputType.number,
      ),
    ),
    btnOkOnPress: () {
      if (priceController.text.trim().isEmpty) return;
      context.read<TripCubit>().changeKiloPrice(
        kiloPrice: double.parse(priceController.text),
      );
    },
    btnCancelOnPress: () {},
    btnOkText: 'تغيير',
    btnCancelText: 'إلغاء',
    reverseBtnOrder: true,
    buttonsTextStyle: AppStyle.styleMedium14.copyWith(color: Colors.white),
  ).show();
}
