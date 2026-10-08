import 'package:equatable/equatable.dart';

double _double(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
DateTime? _date(dynamic v) => DateTime.tryParse(v?.toString() ?? '');

/// A company wallet the captain transfers his dues to.
class CollectionWallet extends Equatable {
  const CollectionWallet({
    required this.id,
    required this.provider,
    required this.providerLabel,
    required this.phoneNumber,
    required this.holderName,
    required this.isOnline,
    this.bankName,
  });

  final int id;
  final String provider; // VodafoneCash | EtisalatCash | InstaPay
  final String providerLabel;
  /// Mobile number, or the InstaPay address for InstaPay.
  final String phoneNumber;
  final String holderName;
  final String? bankName;
  final bool isOnline;

  bool get isVodafone => provider == 'VodafoneCash';
  bool get isInstaPay => provider == 'InstaPay';

  factory CollectionWallet.fromJson(Map<String, dynamic> json) =>
      CollectionWallet(
        id: (json['id'] as num?)?.toInt() ?? 0,
        provider: json['provider']?.toString() ?? '',
        providerLabel: json['providerLabel']?.toString() ?? '',
        phoneNumber: json['phoneNumber']?.toString() ?? '',
        holderName: json['holderName']?.toString() ?? '',
        bankName: json['bankName']?.toString(),
        isOnline: json['isOnline'] == true,
      );

  @override
  List<Object?> get props => [id, provider, phoneNumber, holderName, isOnline];
}

/// The captain's "I transferred X from number Y" request.
class CollectionRequest extends Equatable {
  const CollectionRequest({
    required this.id,
    required this.walletId,
    this.senderPhone,
    this.senderAccount,
    this.senderName,
    required this.amount,
    required this.status,
    this.walletPhone,
    this.provider,
    this.note,
    this.receivedAmount,
    this.createdAt,
    this.resolvedAt,
  });

  final int id;
  final int walletId;
  final String? walletPhone;
  final String? provider;
  final String? senderPhone;
  final String? senderAccount;
  final String? senderName;
  final double amount;
  /// Pending | Confirmed | NeedsReview | Rejected | Expired | Cancelled
  final String status;
  final String? note;
  final double? receivedAmount;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  bool get isPending => status == 'Pending';
  bool get isOpen => status == 'Pending' || status == 'NeedsReview';

  /// Who the transfer came from, as the captain wrote it.
  String get senderLabel => senderPhone ?? senderAccount ?? senderName ?? '';

  String get statusLabel => switch (status) {
    'Pending' => 'في انتظار رسالة الاستلام',
    'Confirmed' => 'اتأكد ✅',
    'NeedsReview' => 'بيتراجع من الإدارة',
    'Rejected' => 'اترفض',
    'Expired' => 'ما وصلش تحويل',
    'Cancelled' => 'اتلغى',
    _ => status,
  };

  factory CollectionRequest.fromJson(Map<String, dynamic> json) =>
      CollectionRequest(
        id: (json['id'] as num?)?.toInt() ?? 0,
        walletId: (json['walletId'] as num?)?.toInt() ?? 0,
        walletPhone: json['walletPhone']?.toString(),
        provider: json['provider']?.toString(),
        senderPhone: json['senderPhone']?.toString(),
        senderAccount: json['senderAccount']?.toString(),
        senderName: json['senderName']?.toString(),
        amount: _double(json['amount']),
        status: json['status']?.toString() ?? '',
        note: json['note']?.toString(),
        receivedAmount: json['receivedAmount'] == null
            ? null
            : _double(json['receivedAmount']),
        createdAt: _date(json['createdAt']),
        resolvedAt: _date(json['resolvedAt']),
      );

  @override
  List<Object?> get props => [id, status, note, receivedAmount, resolvedAt];
}

/// Everything the transfer screen needs.
class MyCollection extends Equatable {
  const MyCollection({
    required this.enabled,
    required this.owedToCompany,
    required this.tolerance,
    required this.mustPay,
    required this.noticeHour,
    required this.deadlineHour,
    required this.inWindow,
    required this.isLocked,
    required this.wallets,
    required this.recent,
    this.deadlineAt,
    this.lockedSince,
    this.pending,
    this.lastSenderPhone,
    this.lastSenderAccount,
    this.lastSenderName,
    this.serverTime,
  });

  final bool enabled;
  final double owedToCompany;
  final double tolerance;
  final bool mustPay;
  final int noticeHour;
  final int deadlineHour;
  final DateTime? deadlineAt;
  final bool inWindow;
  final bool isLocked;
  final DateTime? lockedSince;
  final List<CollectionWallet> wallets;
  final CollectionRequest? pending;
  final List<CollectionRequest> recent;
  final String? lastSenderPhone;
  final String? lastSenderAccount;
  final String? lastSenderName;
  final DateTime? serverTime;

  factory MyCollection.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(dynamic v) => v is List
        ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
    return MyCollection(
      enabled: json['enabled'] == true,
      owedToCompany: _double(json['owedToCompany']),
      tolerance: _double(json['tolerance']),
      mustPay: json['mustPay'] == true,
      noticeHour: (json['noticeHour'] as num?)?.toInt() ?? 20,
      deadlineHour: (json['deadlineHour'] as num?)?.toInt() ?? 0,
      deadlineAt: _date(json['deadlineAt']),
      inWindow: json['inWindow'] == true,
      isLocked: json['isLocked'] == true,
      lockedSince: _date(json['lockedSince']),
      wallets: list(json['wallets']).map(CollectionWallet.fromJson).toList(),
      pending: json['pending'] is Map
          ? CollectionRequest.fromJson(
              Map<String, dynamic>.from(json['pending'] as Map),
            )
          : null,
      recent: list(json['recent']).map(CollectionRequest.fromJson).toList(),
      lastSenderPhone: json['lastSenderPhone']?.toString(),
      lastSenderAccount: json['lastSenderAccount']?.toString(),
      lastSenderName: json['lastSenderName']?.toString(),
      serverTime: _date(json['serverTime']),
    );
  }

  /// "12 بالليل" style label for an hour of the day.
  static String hourLabel(int hour) => switch (hour) {
    0 => '12 بالليل',
    12 => '12 الضهر',
    < 12 => '$hour الصبح',
    _ => '${hour - 12} بالليل',
  };

  @override
  List<Object?> get props => [
    enabled,
    owedToCompany,
    mustPay,
    deadlineAt,
    inWindow,
    isLocked,
    wallets,
    pending,
    recent,
  ];
}
