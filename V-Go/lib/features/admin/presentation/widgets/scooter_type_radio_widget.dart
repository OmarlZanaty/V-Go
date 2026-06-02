import 'package:flutter/material.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';

class ScooterTypeRadioWidget extends StatelessWidget {
  const ScooterTypeRadioWidget({
    required this.scooterType,
    super.key,
    this.onChanged,
  });
  final Function(String)? onChanged;
  final String scooterType;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RadioGroup(
                onChanged: (value) {
                  onChanged!(value!);
                },
                groupValue: scooterType,

                child: Row(
                  children: [
                    Radio<String>(
                      value: ScooterType.electric.name,
                      activeColor: AppColors.primary,
                    ),
                    Text(
                      'كهرباء',
                      style: AppStyle.styleMedium16.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              RadioGroup(
                groupValue: scooterType,
                onChanged: (value) {
                  onChanged!(value!);
                },
                child: Row(
                  children: [
                    Radio<String>(
                      value: ScooterType.gasoline.name,
                      activeColor: AppColors.primary,
                    ),
                    Text(
                      'بنزين',
                      style: AppStyle.styleMedium16.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }
}
