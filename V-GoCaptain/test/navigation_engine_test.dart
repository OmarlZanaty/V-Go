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

  test('one bad fix does not reroute, two in a row do', () {
    final engine = NavigationEngine()..setRoute(route());
    const far = LatLng(30.0400, 31.2340);
    expect(engine.update(far).deviated, isFalse);
    expect(engine.update(far).deviated, isTrue);
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
