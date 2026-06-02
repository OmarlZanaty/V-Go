class AccountantStatisticsModel {
  final PeriodData daily;
  final PeriodData weekly;
  final PeriodData monthly;
  final PeriodData quarterly;
  final PeriodData semiAnnually;
  final PeriodData yearly;

  AccountantStatisticsModel({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.quarterly,
    required this.semiAnnually,
    required this.yearly,
  });

  factory AccountantStatisticsModel.fromJson(Map<String, dynamic> json) {
    return AccountantStatisticsModel(
      daily: PeriodData.fromJson(json['daily']),
      weekly: PeriodData.fromJson(json['weekly']),
      monthly: PeriodData.fromJson(json['monthly']),
      quarterly: PeriodData.fromJson(json['quarterly']),
      semiAnnually: PeriodData.fromJson(json['semiAnnually']),
      yearly: PeriodData.fromJson(json['yearly']),
    );
  }
}

class PeriodData {
  final double revenue;
  final double expenses;

  PeriodData({required this.revenue, required this.expenses});

  factory PeriodData.fromJson(Map<String, dynamic> json) {
    return PeriodData(revenue: json['revenue'], expenses: json['expenses']);
  }
}
