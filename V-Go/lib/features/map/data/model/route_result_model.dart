import 'package:scooter_app/core/maps/csb_map.dart';

class RouteResultModel {
  final List<LatLng> points;
  final double distanceKm;
  final String duration;
  final double durationSeconds;

  RouteResultModel({
    required this.points,
    required this.distanceKm,
    required this.duration,
    this.durationSeconds = 0,
  });
}
