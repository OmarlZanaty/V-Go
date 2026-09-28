import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:v_go_captain/features/navigation/services/navigation_engine.dart';
import 'package:v_go_captain/features/navigation/services/routes_api_service.dart';
import 'package:v_go_captain/features/navigation/utils/distance_helper.dart';

// An L-shaped route: ~222 m north, then ~192 m east (at Cairo's latitude).
const a = LatLng(30.0400, 31.2300);
const b = LatLng(30.0420, 31.2300); // the corner: turn right here
const c = LatLng(30.0420, 31.2320);

NavStep step(String maneuver, double meters, LatLng end) => NavStep(
      instruction: '',
      maneuver: maneuver,
      distanceMeters: meters,
      location: end,
      polyline: const [],
    );

RouteResult route() => RouteResult(
      polyline: const [a, b, c],
      steps: [
        step('DEPART', DistanceHelper.haversine(a, b), b),
        step('TURN_RIGHT', DistanceHelper.haversine(b, c), c),
      ],
      distanceMeters: 414,
      durationSeconds: 100,
    );

LatLng lerp(LatLng p, LatLng q, double t) => LatLng(
    p.latitude + (q.latitude - p.latitude) * t,
    p.longitude + (q.longitude - p.longitude) * t);

void main() {
  test('announces the turn at the corner before reaching it', () {
    final engine = NavigationEngine()..setRoute(route());
    final upd = engine.update(lerp(a, b, 0.5));
    expect(upd.currentStep!.maneuver, 'TURN_RIGHT');
    expect(upd.distanceToManeuver, closeTo(111, 3));
    expect(upd.nextStep!.maneuver, 'DESTINATION');
  });

  test('after the corner the next maneuver is the destination', () {
    final engine = NavigationEngine()..setRoute(route());
    engine.update(lerp(a, b, 0.5));
    final upd = engine.update(lerp(b, c, 0.5));
    expect(upd.currentStep!.maneuver, 'DESTINATION');
    expect(upd.remainingDistance, closeTo(96, 3));
  });

  test('snaps a slightly-off fix onto the line and faces along it', () {
    final engine = NavigationEngine()..setRoute(route());
    // ~10 m west of the northbound leg.
    final upd = engine.update(const LatLng(30.0410, 31.2299));
    expect(upd.snapped!.longitude, closeTo(31.2300, 1e-6));
    expect(upd.routeBearing, closeTo(0, 1));
    expect(upd.deviated, isFalse);
  });

  test('a couple of bad fixes do not reroute, three in a row do', () {
    final engine = NavigationEngine()..setRoute(route());
    const far = LatLng(30.0400, 31.2340);
    expect(engine.update(far).deviated, isFalse);
    expect(engine.update(far).deviated, isFalse);
    expect(engine.update(far).deviated, isTrue);
  });

  test('a parallel street ~60 m away counts as off route even on a poor fix',
      () {
    final engine = NavigationEngine()..setRoute(route());
    // ~58 m east of the northbound leg; accuracy 45 m used to widen the
    // tolerance to 67 m and keep the captain "on route" forever.
    const parallel = LatLng(30.0410, 31.2306);
    NavUpdate? upd;
    for (var i = 0; i < 3; i++) {
      upd = engine.update(parallel, accuracy: 45, speed: 8, heading: 0);
    }
    expect(upd!.deviated, isTrue);
  });

  test('driving against the route direction triggers a reroute', () {
    final engine = NavigationEngine()..setRoute(route());
    engine.update(lerp(a, b, 0.6), speed: 6, heading: 0);
    NavUpdate? upd;
    for (var i = 0; i < 3; i++) {
      // Right on the line, but heading south (route runs north).
      upd = engine.update(lerp(a, b, 0.5), speed: 6, heading: 180);
    }
    expect(upd!.snapped, isNull);
    expect(upd.deviated, isTrue);
  });

  test('does not snap back onto a stretch already driven', () {
    final engine = NavigationEngine()..setRoute(route());
    engine.update(lerp(a, b, 0.5));
    engine.update(lerp(b, c, 0.8)); // well past the corner
    // A fix back on the first leg must not rewind progress.
    final upd = engine.update(lerp(a, b, 0.3));
    expect(upd.snapped, isNull);
    expect(engine.progress, greaterThan(300));
  });

  test('pointAlong walks the route and faces along it', () {
    final engine = NavigationEngine()..setRoute(route());
    final first = engine.pointAlong(111)!;
    expect(first.point.latitude, closeTo(30.0410, 1e-5));
    expect(first.bearing, closeTo(0, 1));
    final second = engine.pointAlong(300)!;
    expect(second.point.latitude, closeTo(30.0420, 1e-6));
    expect(second.bearing, closeTo(90, 1));
    // Clamped to the ends.
    expect(engine.pointAlong(99999)!.point.longitude, closeTo(31.2320, 1e-6));
  });

  test('voice cues fire once each on approach', () {
    final engine = NavigationEngine()..setRoute(route());
    final cues = <VoiceCue>[];
    for (var t = 0.0; t <= 1.0; t += 0.02) {
      final cue = engine.update(lerp(a, b, t)).cue;
      if (cue != VoiceCue.none) cues.add(cue);
    }
    // far/near/now for the turn, then "far" for the destination 192 m on.
    expect(cues, [VoiceCue.far, VoiceCue.near, VoiceCue.now, VoiceCue.far]);
  });
}
