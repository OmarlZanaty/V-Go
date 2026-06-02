import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteResultModel {
  final List<LatLng> points;
  final double distanceKm;
  final String duration;

  RouteResultModel({
    required this.points,
    required this.distanceKm,
    required this.duration,
  });
}
