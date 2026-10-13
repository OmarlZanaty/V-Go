import 'package:flutter/material.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

class GenderRadioWidget extends StatelessWidget {
  const GenderRadioWidget({
    required this.onGenderChanged,
    required this.groupValue,
    this.allowUnspecified = false,
    super.key,
  });
  final Function(String) onGenderChanged;
  // null = nothing chosen yet.
  final String? groupValue;
  // Adds «مش عايز أحدد» (value 'none'): gender is optional for riders
  // (App Review guideline 5.1.1(v)).
  final bool allowUnspecified;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: allowUnspecified ? 1 : 2,
          // Wrap: three choices don't fit one line on a small phone.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              RadioGroup(
                groupValue: groupValue?.toLowerCase(),
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
                groupValue: groupValue?.toLowerCase(),
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
              if (allowUnspecified)
                RadioGroup(
                  groupValue: groupValue?.toLowerCase(),
                  onChanged: (value) {
                    onGenderChanged(value!);
                  },
                  child: Row(
                    children: [
                      const Radio<String>(
                        value: 'none',
                        activeColor: AppColors.primary,
                      ),
                      Text(
                        'مش عايز أحدد',
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
        if (!allowUnspecified) const Expanded(child: SizedBox()),
      ],
    );
  }
}
