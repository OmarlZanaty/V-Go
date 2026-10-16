/// The fare the server will charge for a pickup → destination pair. The app
/// only displays it; the server computes the same value when booking.
class FareQuoteModel {
  final double distanceKm;
  final double price;
  final bool isFreeRide;
  final double riderPrice;
  final int freeRidesLeft;

  /// What the rider's best offer takes off [price] (the company pays it).
  final double discount;
  final String? promotionTitle;

  const FareQuoteModel({
    required this.distanceKm,
    required this.price,
    this.isFreeRide = false,
    double? riderPrice,
    this.freeRidesLeft = 0,
    this.discount = 0,
    this.promotionTitle,
  }) : riderPrice = riderPrice ?? price;

  bool get hasDiscount => discount > 0 && !isFreeRide;

  factory FareQuoteModel.fromJson(Map<String, dynamic> json) => FareQuoteModel(
    distanceKm: ((json['distanceKm'] ?? json['DistanceKm'] ?? 0) as num)
        .toDouble(),
    price: ((json['price'] ?? json['Price'] ?? 0) as num).toDouble(),
    isFreeRide: (json['isFreeRide'] ?? json['IsFreeRide'] ?? false) == true,
    riderPrice: ((json['riderPrice'] ?? json['RiderPrice'] ?? json['price'] ??
                json['Price'] ??
                0)
            as num)
        .toDouble(),
    freeRidesLeft:
        ((json['freeRidesLeft'] ?? json['FreeRidesLeft'] ?? 0) as num).toInt(),
    discount: ((json['discount'] ?? json['Discount'] ?? 0) as num).toDouble(),
    promotionTitle:
        (json['promotionTitle'] ?? json['PromotionTitle'])?.toString(),
  );
}
