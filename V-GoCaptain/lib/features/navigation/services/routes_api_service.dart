import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../utils/polyline_decoder.dart';

/// One turn instruction along the route (from a Routes API "step").
class NavStep {
  /// Driver-facing instruction text (Arabic when languageCode=ar is honoured).
  final String instruction;

  /// Maneuver enum from Google, e.g. TURN_LEFT, ROUNDABOUT_RIGHT, DEPART.
  final String maneuver;

  /// Length of this step in meters.
  final double distanceMeters;

  /// Where the maneuver happens (end of the step / the turn point).
  final LatLng location;

  /// Decoded geometry of just this step (used to refine progress within a step).
  final List<LatLng> polyline;

  const NavStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.location,
    required this.polyline,
  });
}

/// Full route result: drawable geometry plus the ordered step list.
class RouteResult {
  final List<LatLng> polyline;
  final List<NavStep> steps;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.polyline,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  bool get isEmpty => polyline.isEmpty || steps.isEmpty;
}

/// Thrown when the Routes API can't return a usable route. The screen turns this
/// into the Arabic retry banner.
class RoutesApiException implements Exception {
  final String message;
  RoutesApiException(this.message);
  @override
  String toString() => message;
}

/// Calls Google Routes API v2 (`directions/v2:computeRoutes`) and maps the
/// response into a [RouteResult]. Asks for Arabic instructions and metric units.
class RoutesApiService {
  RoutesApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  // Only request the fields we actually use — keeps the response small and is
  // required by the API (an empty field mask returns nothing).
  static const String _fieldMask = 'routes.distanceMeters,'
      'routes.duration,'
      'routes.polyline.encodedPolyline,'
      'routes.legs.steps.navigationInstruction,'
      'routes.legs.steps.distanceMeters,'
      'routes.legs.steps.startLocation,'
      'routes.legs.steps.endLocation,'
      'routes.legs.steps.polyline';

  Future<RouteResult> computeRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final body = {
      'origin': _waypoint(origin),
      'destination': _waypoint(destination),
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': false,
      'languageCode': 'ar',
      'regionCode': 'EG',
      'units': 'METRIC',
    };

    http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': AppConfig.routesApiKey,
              'X-Goog-FieldMask': _fieldMask,
              // Authorize an Android-restricted key for this HTTP call, the same
              // way the Maps SDK authenticates natively. Without these the key
              // returns 403 API_KEY_ANDROID_APP_BLOCKED.
              'X-Android-Package': AppConfig.androidPackage,
              'X-Android-Cert': AppConfig.androidCertSha1,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw RoutesApiException('تعذر الاتصال بخدمة المسار');
    }

    if (res.statusCode != 200) {
      throw RoutesApiException('تعذر تحميل المسار (${res.statusCode})');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw RoutesApiException('استجابة غير صالحة من خدمة المسار');
    }

    final routes = json['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw RoutesApiException('لا يوجد مسار متاح');
    }

    final route = routes.first as Map<String, dynamic>;
    final polyline = PolylineDecoder.decode(
      (route['polyline'] as Map?)?['encodedPolyline'] as String?,
    );

    final steps = <NavStep>[];
    final legs = route['legs'] as List? ?? const [];
    for (final leg in legs) {
      final legSteps = (leg as Map)['steps'] as List? ?? const [];
      for (final raw in legSteps) {
        final step = _parseStep(raw as Map);
        if (step != null) steps.add(step);
      }
    }

    if (polyline.isEmpty) {
      throw RoutesApiException('تعذر قراءة المسار');
    }

    return RouteResult(
      polyline: polyline,
      steps: steps,
      distanceMeters: (route['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: _parseDuration(route['duration']),
    );
  }

  Map<String, dynamic> _waypoint(LatLng p) => {
        'location': {
          'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
        },
      };

  NavStep? _parseStep(Map step) {
    final nav = step['navigationInstruction'] as Map?;
    final endLoc = (step['endLocation'] as Map?)?['latLng'] as Map?;
    final startLoc = (step['startLocation'] as Map?)?['latLng'] as Map?;
    // The maneuver point is the END of the step (where you turn).
    final loc = endLoc ?? startLoc;
    if (loc == null) return null;

    return NavStep(
      instruction: (nav?['instructions'] as String?)?.trim() ?? '',
      maneuver: (nav?['maneuver'] as String?) ?? '',
      distanceMeters: (step['distanceMeters'] as num?)?.toDouble() ?? 0,
      location: LatLng(
        (loc['latitude'] as num).toDouble(),
        (loc['longitude'] as num).toDouble(),
      ),
      polyline: PolylineDecoder.decode(
        (step['polyline'] as Map?)?['encodedPolyline'] as String?,
      ),
    );
  }

  /// Duration arrives as a protobuf string like "1234s".
  double _parseDuration(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll('s', '')) ?? 0;
    }
    return 0;
  }

  void dispose() => _client.close();
}
