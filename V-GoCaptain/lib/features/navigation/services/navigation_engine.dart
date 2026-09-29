import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/distance_helper.dart';
import 'routes_api_service.dart';

/// Which voice cue (if any) should fire on this update for the current step.
enum VoiceCue { none, far, near, now }

/// Immutable snapshot the screen renders after each GPS update.
class NavUpdate {
  final NavStep? currentStep; // the upcoming maneuver
  final NavStep? nextStep; // the maneuver right after it ("then …")
  final double distanceToManeuver; // meters along the route to [currentStep]
  final double distanceToNext; // meters from [currentStep] to [nextStep]
  final double remainingDistance; // meters to final destination
  final double remainingDuration; // seconds to final destination
  final bool deviated; // captain left the route → reroute
  final bool arrived; // within arrival radius of destination
  final VoiceCue cue; // voice prompt to speak this tick
  final int stepIndex;

  /// Captain's position on the route line, or null while off it.
  final LatLng? snapped;

  /// Direction the route runs at [snapped], or null while off it.
  final double? routeBearing;

  /// Index of the route vertex just behind the captain (splits the line into
  /// driven / still-to-drive parts).
  final int segment;

  const NavUpdate({
    required this.currentStep,
    required this.nextStep,
    required this.distanceToManeuver,
    required this.distanceToNext,
    required this.remainingDistance,
    required this.remainingDuration,
    required this.deviated,
    required this.arrived,
    required this.cue,
    required this.stepIndex,
    required this.snapped,
    required this.routeBearing,
    required this.segment,
  });

  static const empty = NavUpdate(
    currentStep: null,
    nextStep: null,
    distanceToManeuver: 0,
    distanceToNext: 0,
    remainingDistance: 0,
    remainingDuration: 0,
    deviated: false,
    arrived: false,
    cue: VoiceCue.none,
    stepIndex: 0,
    snapped: null,
    routeBearing: null,
    segment: 0,
  );
}

/// Stateful route tracker. Feed it the route once, then call [update] on every
/// location fix. Tracks how far along the route line the captain is, and
/// derives everything from that: the upcoming maneuver, distances, off-route
/// detection and voice cues. UI-agnostic and fully testable.
///
/// Google's step N carries the instruction for the maneuver at the START of
/// step N (step 0 is "depart"), so the maneuver ahead is always the first step
/// that begins beyond the captain's progress.
class NavigationEngine {
  NavigationEngine({
    this.deviationThresholdMeters = 30,
    this.arrivalThresholdMeters = 30,
    this.offRouteFixesToReroute = 3,
  });

  final double deviationThresholdMeters;
  final double arrivalThresholdMeters;

  /// Consecutive off-route fixes needed before rerouting, so one GPS jump
  /// (tall buildings, under a bridge) doesn't throw the route away. Fixes
  /// arrive ~1/s, so 3 means a reroute starts ~3 s after leaving the route.
  final int offRouteFixesToReroute;

  /// Heading gap (degrees) between GPS course and the route that counts as
  /// driving the wrong way — e.g. a U-turn or a road that runs right next to
  /// the route, where distance alone can't tell the two apart.
  static const double _wrongWayDegrees = 100;

  /// Extra tolerance is capped here: a looser limit let a parallel street
  /// 50–80 m away count as "on route", so the route never recalculated.
  static const double _maxToleranceMeters = 50;

  /// How far ahead of the current position to look when snapping, so a road
  /// that passes near itself (U-turn, flyover) doesn't pull the arrow back.
  static const double _snapWindowMeters = 500;

  RouteResult? _route;
  List<double> _vertexAt = const []; // route distance of each polyline vertex
  List<double> _maneuverAt = const []; // route distance where step i starts
  double _progress = 0;
  int _segment = 0;
  int _maneuverIndex = 0;
  int _offRouteCount = 0;

  // Voice cues already spoken for the current maneuver (reset on advance).
  bool _farSpoken = false;
  bool _nearSpoken = false;
  bool _nowSpoken = false;

  int get stepIndex => _maneuverIndex;
  RouteResult? get route => _route;

  /// Meters travelled along the route at the last on-route fix.
  double get progress => _progress;

  /// Point and direction of travel [distance] meters along the route —
  /// lets the screen extrapolate the arrow between GPS fixes.
  ({LatLng point, double bearing})? pointAlong(double distance) {
    final at = _locate(distance);
    if (at == null) return null;
    final bearing = DistanceHelper.bearingAlongPath(
        _route!.polyline, PathSnap(point: at.point, segment: at.segment, distance: 0));
    return (point: at.point, bearing: bearing);
  }

  /// The route still ahead of [distance] meters along it — the line drawn in
  /// front of the arrow, with everything behind it cut off.
  List<LatLng> pathAhead(double distance) {
    final path = _route?.polyline ?? const <LatLng>[];
    final at = _locate(distance);
    if (at == null) return path;
    return [at.point, ...path.skip(at.segment + 1)];
  }

  /// Point [distance] meters along the route and the segment it lies on.
  ({LatLng point, int segment})? _locate(double distance) {
    final path = _route?.polyline;
    if (path == null || path.length < 2) return null;
    final d = distance.clamp(0.0, _vertexAt.last);
    // Last vertex at or before d.
    var lo = 0, hi = _vertexAt.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_vertexAt[mid] <= d) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final i = math.min(lo, path.length - 2);
    final segLen = _vertexAt[i + 1] - _vertexAt[i];
    final t = segLen <= 0 ? 0.0 : ((d - _vertexAt[i]) / segLen).clamp(0.0, 1.0);
    final a = path[i], b = path[i + 1];
    return (
      point: LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ),
      segment: i,
    );
  }

  /// Load (or replace, after a reroute) the active route. Resets progress.
  void setRoute(RouteResult route) {
    _route = route;
    final path = route.polyline;

    final vertexAt = List<double>.filled(path.length, 0);
    for (var i = 1; i < path.length; i++) {
      vertexAt[i] = vertexAt[i - 1] + DistanceHelper.haversine(path[i - 1], path[i]);
    }
    _vertexAt = vertexAt;

    // Step lengths come from Google and differ slightly from the decoded
    // line; scale them so maneuvers land on the line we measure against.
    final stepsTotal =
        route.steps.fold<double>(0, (sum, s) => sum + s.distanceMeters);
    final scale = stepsTotal > 0 ? vertexAt.last / stepsTotal : 1.0;
    final maneuverAt = List<double>.filled(route.steps.length, 0);
    for (var i = 1; i < route.steps.length; i++) {
      maneuverAt[i] = maneuverAt[i - 1] + route.steps[i - 1].distanceMeters * scale;
    }
    _maneuverAt = maneuverAt;

    _progress = 0;
    _segment = 0;
    _maneuverIndex = route.steps.length > 1 ? 1 : route.steps.length;
    _offRouteCount = 0;
    _resetCues();
  }

  void _resetCues() {
    _farSpoken = false;
    _nearSpoken = false;
    _nowSpoken = false;
  }

  /// Process a new captain position and emit the render snapshot.
  /// [accuracy] (meters) widens the off-route tolerance on a poor fix;
  /// [speed] (m/s) moves voice cues earlier when going fast.
  /// [heading] is the GPS course (degrees, <0 when unknown).
  NavUpdate update(
    LatLng captain, {
    double accuracy = 0,
    double speed = 0,
    double heading = -1,
  }) {
    final route = _route;
    if (route == null || route.polyline.length < 2 || route.steps.isEmpty) {
      return NavUpdate.empty;
    }
    final path = route.polyline;
    final total = _vertexAt.last;

    final tolerance = math.min(
        _maxToleranceMeters, math.max(deviationThresholdMeters, accuracy * 1.2));

    // Snap near where we were first. If that fails, only look FURTHER along
    // the route (rejoining after a short detour) and with a tighter limit —
    // searching the whole line let the arrow snap back onto a stretch
    // already driven or onto a nearby street, so no reroute ever happened.
    var snap = DistanceHelper.snapToPath(captain, path,
        from: math.max(0, _segment - 2), to: _windowEnd());
    // GPS jitter can put a fix a few meters behind; more than that means the
    // captain turned back, which must not rewind progress.
    if (snap != null && _progressAt(snap) < _progress - _maxBacktrackMeters) {
      snap = null;
    }
    if (snap == null || snap.distance > tolerance) {
      final ahead = DistanceHelper.snapToPath(captain, path, from: _segment);
      snap = ahead != null && ahead.distance <= math.min(tolerance, 25.0)
          ? ahead
          : null;
    }
    var onRoute = snap != null && snap.distance <= tolerance;

    // Moving clearly against the route's direction = wrong way / wrong road.
    if (onRoute && speed > 3 && heading >= 0) {
      final routeDir = DistanceHelper.bearingAlongPath(path, snap);
      final gap = ((heading - routeDir + 540) % 360 - 180).abs();
      if (gap > _wrongWayDegrees) onRoute = false;
    }

    if (onRoute) {
      _offRouteCount = 0;
      _segment = snap!.segment;
      _progress = _progressAt(snap);
    } else {
      _offRouteCount++;
    }

    // Advance past every maneuver the captain has reached.
    while (_maneuverIndex < route.steps.length &&
        _maneuverAt[_maneuverIndex] <= _progress + 5) {
      _maneuverIndex++;
      _resetCues();
    }

    final remaining = math.max(0.0, total - _progress);
    final arrived = DistanceHelper.haversine(captain, path.last) <=
            arrivalThresholdMeters ||
        (onRoute && remaining <= arrivalThresholdMeters);

    final destination = NavStep(
      instruction: '',
      maneuver: 'DESTINATION',
      distanceMeters: 0,
      location: path.last,
      polyline: const [],
    );
    final hasManeuver = _maneuverIndex < route.steps.length;
    final current = hasManeuver ? route.steps[_maneuverIndex] : destination;
    final currentAt = hasManeuver ? _maneuverAt[_maneuverIndex] : total;
    final NavStep? next;
    final double nextAt;
    if (_maneuverIndex + 1 < route.steps.length) {
      next = route.steps[_maneuverIndex + 1];
      nextAt = _maneuverAt[_maneuverIndex + 1];
    } else if (hasManeuver) {
      next = destination;
      nextAt = total;
    } else {
      next = null;
      nextAt = total;
    }
    final distToManeuver = math.max(0.0, currentAt - _progress);

    final remainingDuration = total <= 0
        ? 0.0
        : route.durationSeconds * (remaining / total).clamp(0.0, 1.0);

    return NavUpdate(
      currentStep: current,
      nextStep: next,
      distanceToManeuver: distToManeuver,
      distanceToNext: math.max(0.0, nextAt - currentAt),
      remainingDistance: remaining,
      remainingDuration: remainingDuration,
      deviated: _offRouteCount >= offRouteFixesToReroute && !arrived,
      arrived: arrived,
      cue: _computeCue(distToManeuver, speed, arrived),
      stepIndex: _maneuverIndex,
      snapped: onRoute ? snap!.point : null,
      routeBearing:
          onRoute ? DistanceHelper.bearingAlongPath(path, snap!) : null,
      segment: _segment,
    );
  }

  static const double _maxBacktrackMeters = 30;

  double _progressAt(PathSnap snap) =>
      _vertexAt[snap.segment] +
      DistanceHelper.haversine(_route!.polyline[snap.segment], snap.point);

  /// Last segment index within [_snapWindowMeters] ahead of the captain.
  int _windowEnd() {
    final limit = _progress + _snapWindowMeters;
    var i = _segment;
    while (i < _vertexAt.length - 1 && _vertexAt[i] < limit) {
      i++;
    }
    return i;
  }

  /// Fire each cue once as the captain closes on the maneuver. Distances grow
  /// with speed so there is always ~20 s / ~8 s / ~3 s of warning.
  VoiceCue _computeCue(double dist, double speed, bool arrived) {
    if (arrived) return VoiceCue.none;
    final nowM = math.max(25.0, speed * 3);
    final nearM = math.max(100.0, speed * 8);
    final farM = math.max(300.0, speed * 20);
    if (!_nowSpoken && dist <= nowM) {
      _nowSpoken = _nearSpoken = _farSpoken = true;
      return VoiceCue.now;
    }
    if (!_nearSpoken && dist <= nearM) {
      _nearSpoken = _farSpoken = true;
      return VoiceCue.near;
    }
    if (!_farSpoken && dist <= farM) {
      _farSpoken = true;
      // Too close to be worth a separate "far" call — the near cue follows.
      if (dist <= nearM + 60) return VoiceCue.none;
      return VoiceCue.far;
    }
    return VoiceCue.none;
  }
}
