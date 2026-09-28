import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Result of [DistanceHelper.snapToPath].
class PathSnap {
  final LatLng point; // closest point on the path
  final int segment; // index of the segment start vertex
  final double distance; // meters from the raw position to [point]

  const PathSnap({
    required this.point,
    required this.segment,
    required this.distance,
  });
}

/// Geo math used by the navigation engine: distances (Haversine), bearings, and
/// point-to-polyline projection for deviation detection. Pure functions, no state.
class DistanceHelper {
  DistanceHelper._();

  static const double _earthRadiusM = 6371000.0;

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
  static double _rad2deg(double rad) => rad * (180.0 / math.pi);

  /// Great-circle distance between two points in **meters**.
  static double haversine(LatLng a, LatLng b) {
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Initial bearing (heading) from [a] to [b] in degrees, normalised to 0..360.
  /// Used to rotate the captain arrow and orient the 3D camera.
  static double bearing(LatLng a, LatLng b) {
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final brng = _rad2deg(math.atan2(y, x));
    return (brng + 360.0) % 360.0;
  }

  /// Shortest distance (meters) from [p] to the polyline [path]. Returns
  /// [double.infinity] for an empty path. Projects onto each segment, so a
  /// captain on a long straight road reads ~0 even between vertices.
  static double distanceToPath(LatLng p, List<LatLng> path) {
    if (path.isEmpty) return double.infinity;
    if (path.length == 1) return haversine(p, path.first);

    var best = double.infinity;
    for (var i = 0; i < path.length - 1; i++) {
      final d = _distanceToSegment(p, path[i], path[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }

  /// Closest point on [path] to [p]: where the captain arrow is drawn so it
  /// rides on the route line instead of jittering beside it. [from]/[to]
  /// limit the search to segments `from..to` (vertex indices).
  static PathSnap? snapToPath(LatLng p, List<LatLng> path,
      {int from = 0, int? to}) {
    if (path.length < 2) return null;
    final last = math.min(to ?? path.length - 1, path.length - 1);
    PathSnap? best;
    for (var i = math.max(0, from); i < last; i++) {
      final a = path[i], b = path[i + 1];
      final t = _projectionFactor(p, a, b);
      final point = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final d = haversine(p, point);
      if (best == null || d < best.distance) {
        best = PathSnap(point: point, segment: i, distance: d);
      }
    }
    return best;
  }

  /// Direction of travel along [path] at [snap], measured to a point
  /// [lookAheadM] further along. Stable where GPS heading is noisy (slow
  /// speeds, standing at a light), and never follows the phone's rotation.
  static double bearingAlongPath(List<LatLng> path, PathSnap snap,
      {double lookAheadM = 30}) {
    var from = snap.point;
    var remaining = lookAheadM;
    for (var i = snap.segment + 1; i < path.length; i++) {
      final leg = haversine(from, path[i]);
      if (leg >= remaining || i == path.length - 1) {
        return bearing(snap.point, path[i]);
      }
      remaining -= leg;
      from = path[i];
    }
    return bearing(path[path.length - 2], path.last);
  }

  /// Projection factor t (0..1) of [p] onto segment [a]-[b].
  static double _projectionFactor(LatLng p, LatLng a, LatLng b) {
    final latRef = _deg2rad(a.latitude);
    final bx = _deg2rad(b.longitude - a.longitude) * math.cos(latRef);
    final by = _deg2rad(b.latitude - a.latitude);
    final px = _deg2rad(p.longitude - a.longitude) * math.cos(latRef);
    final py = _deg2rad(p.latitude - a.latitude);
    final segLenSq = bx * bx + by * by;
    if (segLenSq == 0) return 0;
    return ((px * bx + py * by) / segLenSq).clamp(0.0, 1.0);
  }

  /// Distance (meters) from [p] to the segment [a]-[b]. Uses a local
  /// equirectangular projection — accurate at city scale where segments are short.
  static double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    // Project lat/lng to local meters around `a`.
    final latRef = _deg2rad(a.latitude);
    double x(LatLng q) =>
        _deg2rad(q.longitude - a.longitude) * math.cos(latRef) * _earthRadiusM;
    double y(LatLng q) => _deg2rad(q.latitude - a.latitude) * _earthRadiusM;

    final px = x(p), py = y(p);
    final bx = x(b), by = y(b);

    final segLenSq = bx * bx + by * by;
    if (segLenSq == 0) return haversine(p, a);

    // Projection factor t of p onto the segment, clamped to [0,1].
    var t = (px * bx + py * by) / segLenSq;
    t = t.clamp(0.0, 1.0);

    final projX = bx * t;
    final projY = by * t;
    final dx = px - projX;
    final dy = py - projY;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Human-readable Arabic distance: "350 م" under 1 km, otherwise "1.4 كم".
  static String formatDistance(double meters) {
    if (meters.isNaN || meters.isInfinite) return '';
    if (meters < 1000) {
      // Round to the nearest 10 m so the banner doesn't jitter every metre.
      final rounded = (meters / 10).round() * 10;
      return '$rounded م';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} كم';
  }

  /// Human-readable Arabic duration from seconds: "3 د" / "1 س 12 د".
  static String formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '';
    final totalMinutes = (seconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes د';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '$hours س' : '$hours س $minutes د';
  }

  /// Clock ETA ("HH:mm", 24h) from now plus [seconds].
  static String etaClock(double seconds) {
    final arrival = DateTime.now().add(Duration(seconds: seconds.round()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
