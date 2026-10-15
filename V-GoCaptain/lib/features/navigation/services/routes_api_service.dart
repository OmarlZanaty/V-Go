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

  /// No response at all (offline / timeout) — retrying another travel mode
  /// would just wait out a second timeout.
  final bool network;
  RoutesApiException(this.message, {this.network = false});
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

  /// A slower alternative is still preferred when it is shorter and at most
  /// this much slower than the fastest one (captains want the shortcut).
  static const double _maxSlowdownForShortcut = 1.15;

  /// Routes for scooters first (TWO_WHEELER takes the shortcuts cars can't,
  /// and is supported in Egypt), falling back to DRIVE if it fails.
  ///
  /// [heading] (degrees) is the captain's direction of travel: Google then
  /// starts the route the way they're already going instead of asking for a
  /// U-turn. [reroute] skips alternative routes so the answer comes back
  /// faster while the captain is driving off the old line.
  Future<RouteResult> computeRoute({
    required LatLng origin,
    required LatLng destination,
    double? heading,
    bool reroute = false,
  }) async {
    try {
      try {
        return await _computeRoute(
            origin, destination, 'TWO_WHEELER', heading, reroute);
      } on RoutesApiException catch (e) {
        if (e.network) rethrow;
        return await _computeRoute(
            origin, destination, 'DRIVE', heading, reroute);
      }
    } on RoutesApiException catch (googleError) {
      // Google rejects the key while its billing is off (403), so the route
      // line used to disappear. The public OSRM router (same as the rider app
      // and the server) keeps the line and the turn list working.
      try {
        return await _osrmRoute(origin, destination);
      } catch (_) {
        throw googleError;
      }
    }
  }

  static const String _osrmEndpoint =
      'https://router.project-osrm.org/route/v1/driving/';

  Future<RouteResult> _osrmRoute(LatLng origin, LatLng destination) async {
    final uri = Uri.parse(
      '$_osrmEndpoint${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=polyline&steps=true',
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw RoutesApiException('تعذر تحميل المسار (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = json['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw RoutesApiException('لا يوجد مسار متاح');
    }
    final route = routes.first as Map<String, dynamic>;
    final polyline = PolylineDecoder.decode(route['geometry'] as String?);
    if (polyline.isEmpty) throw RoutesApiException('تعذر قراءة المسار');

    final steps = <NavStep>[];
    for (final leg in route['legs'] as List? ?? const []) {
      for (final raw in (leg as Map)['steps'] as List? ?? const []) {
        final step = raw as Map;
        final man = step['maneuver'] as Map? ?? const {};
        final loc = man['location'] as List?;
        if (loc == null || loc.length < 2) continue;
        steps.add(NavStep(
          // Empty → the screen speaks the Arabic phrase for the maneuver.
          instruction: '',
          maneuver: _osrmManeuver(
            man['type'] as String? ?? '',
            man['modifier'] as String? ?? '',
          ),
          distanceMeters: (step['distance'] as num?)?.toDouble() ?? 0,
          location: LatLng(
            (loc[1] as num).toDouble(),
            (loc[0] as num).toDouble(),
          ),
          polyline: PolylineDecoder.decode(step['geometry'] as String?),
        ));
      }
    }
    if (steps.isEmpty) {
      // A route with no turn data still draws: one depart step.
      steps.add(NavStep(
        instruction: '',
        maneuver: 'DEPART',
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        location: polyline.first,
        polyline: polyline,
      ));
    }

    return RouteResult(
      polyline: polyline,
      steps: steps,
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
    );
  }

  /// OSRM maneuver (type + modifier) → the Google maneuver names the
  /// navigation screen's icons and Arabic phrases understand.
  static String _osrmManeuver(String type, String modifier) {
    final left = modifier.contains('left');
    switch (type) {
      case 'depart':
        return 'DEPART';
      case 'arrive':
        return 'DESTINATION';
      case 'roundabout':
      case 'rotary':
      case 'roundabout turn':
      case 'exit roundabout':
      case 'exit rotary':
        return left ? 'ROUNDABOUT_LEFT' : 'ROUNDABOUT_RIGHT';
      case 'fork':
        return left ? 'FORK_LEFT' : 'FORK_RIGHT';
      case 'merge':
        return 'MERGE';
      case 'on ramp':
      case 'off ramp':
        return left ? 'RAMP_LEFT' : 'RAMP_RIGHT';
      case 'new name':
        return 'NAME_CHANGE';
    }
    switch (modifier) {
      case 'uturn':
        return 'UTURN_LEFT';
      case 'sharp left':
        return 'TURN_SHARP_LEFT';
      case 'sharp right':
        return 'TURN_SHARP_RIGHT';
      case 'left':
        return 'TURN_LEFT';
      case 'right':
        return 'TURN_RIGHT';
      case 'slight left':
        return type == 'continue' ? 'KEEP_LEFT' : 'TURN_SLIGHT_LEFT';
      case 'slight right':
        return type == 'continue' ? 'KEEP_RIGHT' : 'TURN_SLIGHT_RIGHT';
      default:
        return 'STRAIGHT';
    }
  }

  Future<RouteResult> _computeRoute(
    LatLng origin,
    LatLng destination,
    String travelMode,
    double? heading,
    bool reroute,
  ) async {
    final body = {
      'origin': _waypoint(origin, heading: heading),
      'destination': _waypoint(destination),
      'travelMode': travelMode,
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': !reroute,
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
          .timeout(Duration(seconds: reroute ? 8 : 15));
    } catch (e) {
      throw RoutesApiException('تعذر الاتصال بخدمة المسار', network: true);
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

    final route = _pickShortest(routes.cast<Map<String, dynamic>>());
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

  /// Shortest route whose duration is within [_maxSlowdownForShortcut] of the
  /// fastest; Google's default pick favours speed and often takes long detours.
  Map<String, dynamic> _pickShortest(List<Map<String, dynamic>> routes) {
    double dist(Map r) => (r['distanceMeters'] as num?)?.toDouble() ?? double.infinity;
    final fastest = routes
        .map((r) => _parseDuration(r['duration']))
        .reduce((a, b) => a < b ? a : b);
    var best = routes.first;
    for (final r in routes) {
      final acceptable =
          _parseDuration(r['duration']) <= fastest * _maxSlowdownForShortcut;
      if (acceptable && dist(r) < dist(best)) best = r;
    }
    return best;
  }

  Map<String, dynamic> _waypoint(LatLng p, {double? heading}) => {
        'location': {
          'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
          if (heading != null) 'heading': heading.round() % 360,
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
