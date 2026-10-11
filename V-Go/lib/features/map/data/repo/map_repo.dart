import 'dart:developer';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/map_service.dart';
import '../../../../core/utils/model/edit_distance_result_model.dart';
import '../../../../core/utils/model/location_model.dart';
import '../model/place_suggestion_model.dart';
import '../model/route_result_model.dart';

class MapRepo {
  final LocationService locationService;
  final MapService mapService;

  MapRepo({required this.locationService, required this.mapService});

  Future<LocationModel> getCurrentLocation() async {
    return await locationService.getCurrentLocation();
  }

  Stream<LocationModel> getLocationStream() {
    return locationService.getLocationStream();
  }

  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // Google first (street-level, Arabic); the device geocoder is the fallback.
    final google = await mapService.reverseGeocode(latitude, longitude);
    if (google != null) return google;
    return await locationService.getAddressFromCoordinates(latitude, longitude);
  }

  // After a provider fails, skip it for a while instead of waiting on it for
  // every route (Google answers 403 instantly; an unreachable OSRM times out).
  static const _providerCooldown = Duration(minutes: 5);
  DateTime? _googleDownUntil;
  DateTime? _osrmDownUntil;

  bool _isDown(DateTime? until) =>
      until != null && DateTime.now().isBefore(until);

  /// Scooter route — the same road the captain app navigates, so the line, the
  /// distance and the fare (distance × price/km) all match the actual ride.
  /// Falls back to a car route, then OSRM, then a straight-line estimate, so a
  /// ride can always be requested.
  Future<RouteResultModel> getRoute(
    LocationModel from,
    LocationModel to,
  ) async {
    if (!_isDown(_googleDownUntil)) {
      try {
        return await mapService.getRouteBetweenLocations(
          from,
          to,
          travelMode: 'TWO_WHEELER',
        );
      } catch (_) {}
      try {
        return await mapService.getRouteBetweenLocations(from, to);
      } catch (e) {
        log('Google route failed, using fallback: $e');
        _googleDownUntil = DateTime.now().add(_providerCooldown);
      }
    }
    if (!_isDown(_osrmDownUntil)) {
      try {
        return await mapService.getOsrmRoute(from, to);
      } catch (e) {
        log('OSRM route failed, using straight line: $e');
        _osrmDownUntil = DateTime.now().add(_providerCooldown);
      }
    }
    return mapService.straightLineRoute(from, to);
  }

  Future<List<PlaceSuggestionModel>> getPlaceSuggestions(
    String query,
    String sessionToken, {
    double? originLat,
    double? originLng,
  }) async {
    if (!_isDown(_googleDownUntil)) {
      try {
        return await mapService.getPlaceSuggestions(
          query,
          sessionToken,
          originLat: originLat,
          originLng: originLng,
        );
      } catch (e) {
        log('Google places failed, using Photon: $e');
        _googleDownUntil = DateTime.now().add(_providerCooldown);
      }
    }
    return await mapService.getPhotonSuggestions(
      query,
      originLat: originLat,
      originLng: originLng,
    );
  }

  Future<LocationModel> getPlaceLocation(String placeId) async {
    return await mapService.getPlaceLocation(placeId);
  }

  Future<EtaDistanceResult?> getEstimatedTimeOfArrivalWithDistance(
    LocationModel from,
    LocationModel to,
  ) async {
    // Live trip ETA: the captain rides a scooter, so time it as one.
    if (!_isDown(_googleDownUntil)) {
      final eta =
          await mapService.getEstimatedTimeOfArrival(
            from,
            to,
            travelMode: 'TWO_WHEELER',
          ) ??
          await mapService.getEstimatedTimeOfArrival(from, to);
      if (eta != null) return eta;
      _googleDownUntil = DateTime.now().add(_providerCooldown);
    }
    final r = await getRoute(from, to);
    return EtaDistanceResult(
      eta: Duration(seconds: r.durationSeconds.round()),
      distanceMeters: (r.distanceKm * 1000).round(),
    );
  }
}
