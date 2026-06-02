import 'package:flutter/material.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/user_model.dart';

class DriverFinanceSection extends StatefulWidget {
  const DriverFinanceSection({required this.profit, super.key});
  final ProfitModel profit;
  @override
  State<DriverFinanceSection> createState() => _DriverFinanceSectionState();
}

class _DriverFinanceSectionState extends State<DriverFinanceSection> {
  String _selectedPeriod = 'ربح اليوم';
  double? currentProfit;

  @override
  void initState() {
    currentProfit = widget.profit.dailyProfit.toDouble();
    super.initState();
  }

  final List<String> _periodOptions = [
    'ربح اليوم',
    'ربح الاسبوع',
    'ربح الشهر',
    'الاجمالي',
  ];

  void _onPeriodSelected(String period) {
    setState(() {
      _selectedPeriod = period;
      currentProfit = _changeProfit(period);
    });
  }

  double _changeProfit(String period) {
    switch (period) {
      case 'ربح اليوم':
        return widget.profit.dailyProfit.toDouble();
      case 'ربح الاسبوع':
        return widget.profit.weeklyProfit.toDouble();
      case 'ربح الشهر':
        return widget.profit.monthlyProfit.toDouble();
      case 'الاجمالي':
        return widget.profit.allTimeProfit.toDouble();
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 4, right: 16),
      decoration: const BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedPeriod,
                style: AppStyle.styleMedium14.copyWith(color: Colors.white),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert),
                onSelected: _onPeriodSelected,
                elevation: 2,
                color: AppColors.darkGrey,
                itemBuilder: (BuildContext context) => _periodOptions
                    .map(
                      (period) => PopupMenuItem<String>(
                        value: period,
                        child: Text(
                          period,
                          style: AppStyle.styleMedium14.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                currentProfit.toString(),
                style: AppStyle.styleBold20.copyWith(color: Colors.white),
              ),
              horizontalSpace(8),
              Text(
                'ج.م',
                style: AppStyle.styleMedium14.copyWith(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
