import 'package:flutter/material.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

class GenderRadioWidget extends StatelessWidget {
  const GenderRadioWidget({
    required this.onGenderChanged,
    required this.groupValue,
    super.key,
  });
  final Function(String) onGenderChanged;
  final String groupValue;
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
                groupValue: groupValue.toLowerCase(),
                onChanged: (value) {
                  onGenderChanged(value!);
                },
                child: Row(
                  children: [
                    const Radio<String>(
                      value: 'male',
                      activeColor: AppColors.primary,
                    ),
                    Text(
                      'ذكر',
                      style: AppStyle.styleMedium16.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              RadioGroup(
                groupValue: groupValue.toLowerCase(),
                onChanged: (value) {
                  onGenderChanged(value!);
                },
                child: Row(
                  children: [
                    const Radio<String>(
                      value: 'female',
                      activeColor: AppColors.primary,
                    ),
                    Text(
                      'انثى',
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
