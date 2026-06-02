import 'dart:math';

String calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371; // Earth's radius in kilometers

  // Convert latitude and longitude from degrees to radians
  final double lat1Rad = lat1 * pi / 180;
  final double lon1Rad = lon1 * pi / 180;
  final double lat2Rad = lat2 * pi / 180;
  final double lon2Rad = lon2 * pi / 180;

  // Differences in coordinates
  final double dLat = lat2Rad - lat1Rad;
  final double dLon = lon2Rad - lon1Rad;

  // Haversine formula
  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  // Distance in kilometers
  final double distance = earthRadius * c;
  if (distance < 1.0) return '${(distance * 1000).toStringAsFixed(0)} متر';
  return '${distance.toStringAsFixed(1)} كم';
}
