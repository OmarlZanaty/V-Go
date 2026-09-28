import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Closest point on a route line, see [GeoUtils.snapToPath].
class PathSnap {
  final LatLng point; // closest point on the path
  final int segment; // index of the segment's start vertex
  final double distance; // meters from the query point to [point]

  const PathSnap(this.point, this.segment, this.distance);
}

/// Small geo helpers for live captain tracking.
class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusM = 6371000.0;
  static double _rad(double deg) => deg * math.pi / 180.0;

  /// Great-circle distance in meters.
  static double haversine(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Closest point on [path] to [p], or null for a path under 2 points.
  static PathSnap? snapToPath(LatLng p, List<LatLng> path) {
    if (path.length < 2) return null;
    PathSnap? best;
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i], b = path[i + 1];
      // Local flat projection around `a` — fine at city scale.
      final k = math.cos(_rad(a.latitude));
      final bx = (b.longitude - a.longitude) * k, by = b.latitude - a.latitude;
      final px = (p.longitude - a.longitude) * k, py = p.latitude - a.latitude;
      final len = bx * bx + by * by;
      final t = len == 0 ? 0.0 : ((px * bx + py * by) / len).clamp(0.0, 1.0);
      final point = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final d = haversine(p, point);
      if (best == null || d < best.distance) best = PathSnap(point, i, d);
    }
    return best;
  }
}
