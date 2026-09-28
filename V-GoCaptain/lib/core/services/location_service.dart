import 'dart:async';

import 'package:flutter/foundation.dart';

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

  /// [distanceFilter] is 15 m for idle live-location pushes; turn-by-turn
  /// passes a small value so the arrow moves smoothly instead of jumping.
  ///
  /// Platform settings matter: with the generic [LocationSettings] Android
  /// only delivers a fix every 5 s, which made the nav arrow lag and reroutes
  /// take 10 s+. [interval] asks the fused provider for faster fixes.
  ///
  /// [keepAliveInBackground] runs the stream in an Android foreground service
  /// (ongoing notification), so location keeps flowing — and the rider keeps
  /// seeing the captain move — when the captain switches app or locks the
  /// screen. Note: on Android the plugin shares ONE native stream, so the
  /// first caller's settings (the online stream) apply to later callers too.
  Stream<Position> positionStream({
    int distanceFilter = 15,
    Duration interval = const Duration(seconds: 5),
    bool keepAliveInBackground = false,
  }) {
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
        intervalDuration: interval,
        foregroundNotificationConfig: keepAliveInBackground
            ? const ForegroundNotificationConfig(
                notificationTitle: 'V-Go Captain',
                notificationText: 'أنت متصل — يتم مشاركة موقعك لاستقبال الرحلات',
                notificationChannelName: 'الموقع أثناء الاتصال',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}
