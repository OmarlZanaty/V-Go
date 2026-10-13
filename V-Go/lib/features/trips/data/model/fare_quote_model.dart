/// The fare the server will charge for a pickup → destination pair. The app
/// only displays it; the server computes the same value when booking.
class FareQuoteModel {
  final double distanceKm;
  final double price;

  const FareQuoteModel({required this.distanceKm, required this.price});

  factory FareQuoteModel.fromJson(Map<String, dynamic> json) => FareQuoteModel(
    distanceKm: ((json['distanceKm'] ?? json['DistanceKm'] ?? 0) as num)
        .toDouble(),
    price: ((json['price'] ?? json['Price'] ?? 0) as num).toDouble(),
  );
}
