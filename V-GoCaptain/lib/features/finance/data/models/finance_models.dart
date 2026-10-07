import 'package:equatable/equatable.dart';

class FinanceEligibility extends Equatable {
  const FinanceEligibility({
    required this.canGoOnline,
    this.code,
    this.message,
  });

  final bool canGoOnline;
  final String? code;
  final String? message;

  factory FinanceEligibility.fromJson(Map<String, dynamic> json) {
    return FinanceEligibility(
      canGoOnline: json['canGoOnline'] == true || json['CanGoOnline'] == true,
      code: (json['code'] ?? json['Code'])?.toString(),
      message: (json['message'] ?? json['Message'])?.toString(),
    );
  }

  @override
  List<Object?> get props => [canGoOnline, code, message];
}

class FinancePeriodStats extends Equatable {
  const FinancePeriodStats({
    required this.trips,
    required this.grossFare,
    required this.companyCommission,
    required this.driverNet,
    required this.cashCollected,
    required this.onlineCollected,
  });

  final int trips;
  final double grossFare;
  final double companyCommission;
  final double driverNet;
  final double cashCollected;
  final double onlineCollected;

  factory FinancePeriodStats.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const <String, dynamic>{};
    return FinancePeriodStats(
      trips: _int(map['trips']),
      grossFare: _double(map['grossFare']),
      companyCommission: _double(map['companyCommission']),
      driverNet: _double(map['driverNet']),
      cashCollected: _double(map['cashCollected']),
      onlineCollected: _double(map['onlineCollected']),
    );
  }

  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  @override
  List<Object?> get props => [
    trips,
    grossFare,
    companyCommission,
    driverNet,
    cashCollected,
    onlineCollected,
  ];
}

class FinanceSummary extends Equatable {
  const FinanceSummary({
    required this.balance,
    required this.owedToCompany,
    required this.owedToDriver,
    required this.companyCommissionPercent,
    required this.cashLimit,
    required this.warningPercent,
    required this.limitUsedPercent,
    required this.isNearLimit,
    required this.isLocked,
    this.collectionEnabled = false,
    this.collectionLocked = false,
    this.collectionTolerance = 0,
    required this.today,
    required this.week,
    required this.month,
    required this.allTime,
    this.payoutMethod,
    this.payoutAccount,
    this.payoutAccountName,
    this.payoutUpdatedAt,
    this.verificationStatus,
    this.eligibility,
  });

  final double balance;
  final double owedToCompany;
  final double owedToDriver;
  final double companyCommissionPercent;
  final double cashLimit;
  final double warningPercent;
  final double limitUsedPercent;
  final bool isNearLimit;
  final bool isLocked;
  // Daily wallet collection (replaces Paymob settlement once enabled).
  final bool collectionEnabled;
  final bool collectionLocked;
  final double collectionTolerance;
  final FinancePeriodStats today;
  final FinancePeriodStats week;
  final FinancePeriodStats month;
  final FinancePeriodStats allTime;
  final String? payoutMethod;
  final String? payoutAccount;
  final String? payoutAccountName;
  final DateTime? payoutUpdatedAt;
  final String? verificationStatus;
  final FinanceEligibility? eligibility;

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    return FinanceSummary(
      balance: _double(json['balance']),
      owedToCompany: _double(json['owedToCompany']),
      owedToDriver: _double(json['owedToDriver']),
      companyCommissionPercent: _double(json['companyCommissionPercent']),
      cashLimit: _double(json['cashLimit']),
      warningPercent: _double(json['warningPercent']),
      limitUsedPercent: _double(json['limitUsedPercent']),
      isNearLimit: json['isNearLimit'] == true,
      isLocked: json['isLocked'] == true,
      collectionEnabled: json['collectionEnabled'] == true,
      collectionLocked: json['collectionLocked'] == true,
      collectionTolerance: _double(json['collectionTolerance']),
      today: FinancePeriodStats.fromJson(_map(json['today'])),
      week: FinancePeriodStats.fromJson(_map(json['week'])),
      month: FinancePeriodStats.fromJson(_map(json['month'])),
      allTime: FinancePeriodStats.fromJson(_map(json['allTime'])),
      payoutMethod: json['payoutMethod']?.toString(),
      payoutAccount: json['payoutAccount']?.toString(),
      payoutAccountName: json['payoutAccountName']?.toString(),
      payoutUpdatedAt: DateTime.tryParse(
        json['payoutUpdatedAt']?.toString() ?? '',
      ),
      verificationStatus: json['verificationStatus']?.toString(),
      eligibility: json['eligibility'] is Map
          ? FinanceEligibility.fromJson(
              Map<String, dynamic>.from(json['eligibility'] as Map),
            )
          : null,
    );
  }

  FinancePeriodStats statsFor(FinanceRange range) {
    return switch (range) {
      FinanceRange.today => today,
      FinanceRange.week => week,
      FinanceRange.month => month,
      FinanceRange.all => allTime,
    };
  }

  static Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  @override
  List<Object?> get props => [
    balance,
    owedToCompany,
    owedToDriver,
    companyCommissionPercent,
    cashLimit,
    warningPercent,
    limitUsedPercent,
    isNearLimit,
    isLocked,
    collectionEnabled,
    collectionLocked,
    collectionTolerance,
    today,
    week,
    month,
    allTime,
    payoutMethod,
    payoutAccount,
    payoutAccountName,
    payoutUpdatedAt,
    verificationStatus,
    eligibility,
  ];
}

enum FinanceRange { today, week, month, all }

extension FinanceRangeX on FinanceRange {
  String get label => switch (this) {
    FinanceRange.today => 'اليوم',
    FinanceRange.week => 'الأسبوع',
    FinanceRange.month => 'الشهر',
    FinanceRange.all => 'الكل',
  };
}

class FinanceLedgerEntry extends Equatable {
  const FinanceLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.tripId,
    this.tripFare,
    this.commissionPercent,
    this.commissionAmount,
    this.driverNet,
    this.tripPaymentMethod,
    this.paymentId,
    this.description,
    this.reference,
    this.createdAt,
  });

  final int id;
  final String type;
  final double amount;
  final String? tripId;
  final double? tripFare;
  final double? commissionPercent;
  final double? commissionAmount;
  final double? driverNet;
  final String? tripPaymentMethod;
  final String? paymentId;
  final String? description;
  final String? reference;
  final DateTime? createdAt;

  bool get isTripEntry =>
      type == 'TripCashCommission' ||
      type == 'TripCardEarning' ||
      type == 'TripCorrection';

  bool get isPayout => type == 'Payout';

  factory FinanceLedgerEntry.fromJson(Map<String, dynamic> json) {
    return FinanceLedgerEntry(
      id: _int(json['id']),
      type: json['type']?.toString() ?? '',
      amount: _double(json['amount']),
      tripId: json['tripId']?.toString(),
      tripFare: _nullableDouble(json['tripFare']),
      commissionPercent: _nullableDouble(json['commissionPercent']),
      commissionAmount: _nullableDouble(json['commissionAmount']),
      driverNet: _nullableDouble(json['driverNet']),
      tripPaymentMethod: json['tripPaymentMethod']?.toString(),
      paymentId: json['paymentId']?.toString(),
      description: json['description']?.toString(),
      reference: json['reference']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    return _double(value);
  }

  @override
  List<Object?> get props => [
    id,
    type,
    amount,
    tripId,
    tripFare,
    commissionPercent,
    commissionAmount,
    driverNet,
    tripPaymentMethod,
    paymentId,
    description,
    reference,
    createdAt,
  ];
}

class FinanceLedgerPage extends Equatable {
  const FinanceLedgerPage({
    required this.items,
    required this.pageNumber,
    required this.hasNextPage,
  });

  final List<FinanceLedgerEntry> items;
  final int pageNumber;
  final bool hasNextPage;

  factory FinanceLedgerPage.fromJson(Map<String, dynamic> json) {
    final list = json['data'] ?? const [];
    return FinanceLedgerPage(
      items: (list as List)
          .whereType<Map>()
          .map((e) => FinanceLedgerEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pageNumber: FinancePeriodStats._int(json['pageNumber']),
      hasNextPage: json['hasNextPage'] == true,
    );
  }

  @override
  List<Object?> get props => [items, pageNumber, hasNextPage];
}

class FinanceSettlementCheckout extends Equatable {
  const FinanceSettlementCheckout({
    required this.paymentId,
    required this.amount,
    required this.checkoutUrl,
  });

  final String paymentId;
  final double amount;
  final String checkoutUrl;

  factory FinanceSettlementCheckout.fromJson(Map<String, dynamic> json) {
    return FinanceSettlementCheckout(
      paymentId: json['paymentId']?.toString() ?? '',
      amount: FinanceSummary._double(json['amount']),
      checkoutUrl: json['checkoutUrl']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [paymentId, amount, checkoutUrl];
}

class FinanceSettlementStatus extends Equatable {
  const FinanceSettlementStatus({
    required this.paymentId,
    required this.amount,
    required this.status,
    required this.credited,
    required this.balance,
    required this.canGoOnline,
  });

  final String paymentId;
  final double amount;
  final String status;
  final bool credited;
  final double balance;
  final bool canGoOnline;

  bool get isFailed => status.toLowerCase() == 'failed';

  factory FinanceSettlementStatus.fromJson(Map<String, dynamic> json) {
    return FinanceSettlementStatus(
      paymentId: json['paymentId']?.toString() ?? '',
      amount: FinanceSummary._double(json['amount']),
      status: json['status']?.toString() ?? '',
      credited: json['credited'] == true,
      balance: FinanceSummary._double(json['balance']),
      canGoOnline: json['canGoOnline'] == true,
    );
  }

  @override
  List<Object?> get props => [
    paymentId,
    amount,
    status,
    credited,
    balance,
    canGoOnline,
  ];
}
