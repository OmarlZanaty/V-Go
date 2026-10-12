/// Fare = distance × price per km, rounded up to a whole pound — the same
/// formula the server uses (no opening fee, no minimum fare).
double calculateTripFare({
  required double distanceKm,
  required double pricePerKilometer,
}) {
  final safeDistanceKm = distanceKm < 0 ? 0.0 : distanceKm;
  final safePricePerKilometer = pricePerKilometer < 0 ? 0.0 : pricePerKilometer;
  return (safePricePerKilometer * safeDistanceKm).ceilToDouble();
}
