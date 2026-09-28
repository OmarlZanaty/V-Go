import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Thin wrapper around geolocator: permission handling, one-shot position,
/// and a movement-filtered stream used to push the driver's live location.
class LocationService {
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  /// Check-only: true if location permission is already granted (does NOT prompt).
  Future<bool> hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  /// One-shot fix, capped at [timeLimit] so a weak GPS signal (indoors) can't
  /// hang the caller; falls back to the last known position on timeout.
  Future<Position> currentPosition({
    Duration timeLimit = const Duration(seconds: 8),
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  /// [distanceFilter] is 15 m for live-location pushes; turn-by-turn passes a
  /// small value so the arrow moves smoothly instead of jumping.
  Stream<Position> positionStream({int distanceFilter = 15}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        distanceFilter: distanceFilter,
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }
}
