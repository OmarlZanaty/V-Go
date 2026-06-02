double calculateTripFare({
  required double distanceKm,
  required double pricePerKilometer,
}) {
  const double baseFare = 5.0;
  const double minimumFare = 10.0;

  final safeDistanceKm = distanceKm < 0 ? 0.0 : distanceKm;
  final safePricePerKilometer = pricePerKilometer < 0 ? 0.0 : pricePerKilometer;

  final totalFare = (safePricePerKilometer * safeDistanceKm) + baseFare;
  if (totalFare < minimumFare) {
    return minimumFare;
  }
  return totalFare;
}
