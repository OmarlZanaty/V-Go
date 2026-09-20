import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/distance_helper.dart';
import 'routes_api_service.dart';

/// Which voice cue (if any) should fire on this update for the current step.
enum VoiceCue { none, far, near, now }

/// Immutable snapshot the screen renders after each GPS update.
class NavUpdate {
  final NavStep? currentStep;
  final NavStep? nextStep;
  final double distanceToManeuver; // meters to the current step's turn point
  final double remainingDistance; // meters to final destination
  final double remainingDuration; // seconds to final destination
  final bool deviated; // captain left the route → reroute
  final bool arrived; // within arrival radius of destination
  final VoiceCue cue; // voice prompt to speak this tick
  final int stepIndex;

  const NavUpdate({
    required this.currentStep,
    required this.nextStep,
    required this.distanceToManeuver,
    required this.remainingDistance,
    required this.remainingDuration,
    required this.deviated,
    required this.arrived,
    required this.cue,
    required this.stepIndex,
  });
}

/// Stateful step-tracker. Feed it the route once, then call [update] on every
/// location fix. Owns: current-step advancement, off-route detection, and
/// per-step voice-cue bookkeeping. UI-agnostic and fully testable.
class NavigationEngine {
  NavigationEngine({
    this.advanceThresholdMeters = 20,
    this.deviationThresholdMeters = 50,
    this.arrivalThresholdMeters = 30,
    this.farCueMeters = 300,
    this.nearCueMeters = 100,
  });

  final double advanceThresholdMeters;
  final double deviationThresholdMeters;
  final double arrivalThresholdMeters;
  final double farCueMeters;
  final double nearCueMeters;

  RouteResult? _route;
  int _stepIndex = 0;

  // Cumulative step distances from each step's start to the destination, so
  // remaining distance is O(1) per update instead of re-summing every tick.
  List<double> _distanceAfterStep = const [];

  // Voice cues already spoken for the current step (reset on advance).
  bool _farSpoken = false;
  bool _nearSpoken = false;
  bool _nowSpoken = false;

  int get stepIndex => _stepIndex;
  RouteResult? get route => _route;

  /// Load (or replace, after a reroute) the active route. Resets progress.
  void setRoute(RouteResult route) {
    _route = route;
    _stepIndex = 0;
    _resetCues();

    // Precompute suffix sums of step lengths.
    final n = route.steps.length;
    final suffix = List<double>.filled(n + 1, 0);
    for (var i = n - 1; i >= 0; i--) {
      suffix[i] = suffix[i + 1] + route.steps[i].distanceMeters;
    }
    _distanceAfterStep = suffix;
  }

  void _resetCues() {
    _farSpoken = false;
    _nearSpoken = false;
    _nowSpoken = false;
  }

  /// Process a new captain position and emit the render snapshot.
  NavUpdate update(LatLng captain) {
    final route = _route;
    if (route == null || route.steps.isEmpty) {
      return const NavUpdate(
        currentStep: null,
        nextStep: null,
        distanceToManeuver: 0,
        remainingDistance: 0,
        remainingDuration: 0,
        deviated: false,
        arrived: false,
        cue: VoiceCue.none,
        stepIndex: 0,
      );
    }

    final destination = route.polyline.last;
    final distanceToDestination = DistanceHelper.haversine(captain, destination);

    // Off-route check first — if deviated, the screen reroutes and the rest of
    // this snapshot is moot.
    final offRoute =
        DistanceHelper.distanceToPath(captain, route.polyline) >
            deviationThresholdMeters;

    // Auto-advance: pass the current maneuver point, move to the next step.
    var step = route.steps[_stepIndex];
    var distToManeuver = DistanceHelper.haversine(captain, step.location);
    if (distToManeuver <= advanceThresholdMeters &&
        _stepIndex < route.steps.length - 1) {
      _stepIndex++;
      _resetCues();
      step = route.steps[_stepIndex];
      distToManeuver = DistanceHelper.haversine(captain, step.location);
    }

    final arrived = distanceToDestination <= arrivalThresholdMeters;

    // Remaining distance = distance to the end of the current step's maneuver
    // (≈ distToManeuver) + everything after this step.
    final remainingDistance =
        distToManeuver + _distanceAfterStep[(_stepIndex + 1)];

    // Scale the route's total duration by how much distance is left.
    final remainingDuration = route.distanceMeters <= 0
        ? 0.0
        : route.durationSeconds * (remainingDistance / route.distanceMeters)
            .clamp(0.0, 1.0);

    final cue = _computeCue(distToManeuver, arrived);

    return NavUpdate(
      currentStep: step,
      nextStep: _stepIndex < route.steps.length - 1
          ? route.steps[_stepIndex + 1]
          : null,
      distanceToManeuver: distToManeuver,
      remainingDistance: remainingDistance,
      remainingDuration: remainingDuration,
      deviated: offRoute && !arrived,
      arrived: arrived,
      cue: cue,
      stepIndex: _stepIndex,
    );
  }

  /// Fire each cue once as the captain closes on the maneuver: 300 m, 100 m, now.
  VoiceCue _computeCue(double distToManeuver, bool arrived) {
    if (arrived) return VoiceCue.none;
    if (!_nowSpoken && distToManeuver <= arrivalThresholdMeters) {
      _nowSpoken = true;
      return VoiceCue.now;
    }
    if (!_nearSpoken && distToManeuver <= nearCueMeters) {
      _nearSpoken = true;
      return VoiceCue.near;
    }
    if (!_farSpoken && distToManeuver <= farCueMeters) {
      _farSpoken = true;
      return VoiceCue.far;
    }
    return VoiceCue.none;
  }
}
