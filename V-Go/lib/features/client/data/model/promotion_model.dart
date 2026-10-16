/// An offer the rider can use now (GET Promotions/mine).
class PromotionModel {
  final int id;
  final String title;
  final String? description;

  /// 1 free ride, 2 percent off, 3 fixed amount off.
  final int type;
  final double value;
  final double? maxDiscount;
  final int ridesLeft;
  final int ridesPerRider;
  final DateTime? endsAt;
  final String? code;

  const PromotionModel({
    required this.id,
    required this.title,
    required this.type,
    required this.value,
    required this.ridesLeft,
    required this.ridesPerRider,
    this.description,
    this.maxDiscount,
    this.endsAt,
    this.code,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    num n(String k) => (json[k] ?? json[k[0].toUpperCase() + k.substring(1)] ?? 0) as num;
    final ends = json['endsAt'] ?? json['EndsAt'];
    final max = json['maxDiscount'] ?? json['MaxDiscount'];
    return PromotionModel(
      id: n('id').toInt(),
      title: (json['title'] ?? json['Title'] ?? '').toString(),
      description: (json['description'] ?? json['Description'])?.toString(),
      type: n('type').toInt(),
      value: n('value').toDouble(),
      maxDiscount: max == null ? null : (max as num).toDouble(),
      ridesLeft: n('ridesLeft').toInt(),
      ridesPerRider: n('ridesPerRider').toInt(),
      endsAt: ends == null ? null : DateTime.tryParse(ends.toString()),
      code: (json['code'] ?? json['Code'])?.toString(),
    );
  }

  /// "الرحلة مجانية" / "خصم 20% (حتى 10 ج.م)" / "خصم 15 ج.م".
  String get offerLabel {
    String pounds(double v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} ج.م';
    switch (type) {
      case 1:
        return 'الرحلة مجانية بالكامل';
      case 2:
        final cap = maxDiscount != null ? ' (حتى ${pounds(maxDiscount!)})' : '';
        return 'خصم ${value.toStringAsFixed(0)}%$cap';
      default:
        return 'خصم ${pounds(value)}';
    }
  }
}
