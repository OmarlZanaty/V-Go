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

  /// Scooter route — the same road the captain app navigates, so the line, the
  /// distance and the fare (distance × price/km) all match the actual ride.
  /// Falls back to a car route if two-wheeler routing fails.
  Future<RouteResultModel> getRoute(
    LocationModel from,
    LocationModel to,
  ) async {
    try {
      return await mapService.getRouteBetweenLocations(
        from,
        to,
        travelMode: 'TWO_WHEELER',
      );
    } catch (_) {
      return await mapService.getRouteBetweenLocations(from, to);
    }
  }

  Future<List<PlaceSuggestionModel>> getPlaceSuggestions(
    String query,
    String sessionToken, {
    double? originLat,
    double? originLng,
  }) async {
    return await mapService.getPlaceSuggestions(
      query,
      sessionToken,
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
    return await mapService.getEstimatedTimeOfArrival(
          from,
          to,
          travelMode: 'TWO_WHEELER',
        ) ??
        await mapService.getEstimatedTimeOfArrival(from, to);
  }
}
