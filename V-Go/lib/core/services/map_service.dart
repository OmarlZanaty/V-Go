import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../features/map/data/model/place_suggestion_model.dart';
import '../../features/map/data/model/route_result_model.dart';
import '../helpers/convert_time.dart';
import '../utils/model/edit_distance_result_model.dart';
import '../utils/model/location_model.dart';

class MapService {
  final Dio dio;
  // Supplied at build time via --dart-define=MAPS_API_KEY=... (CI / production
  // builds should pass a key restricted by package name + SHA). The literal below
  // is only a dev fallback and should be rotated.
  static const String _apiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDpdwRptK8i3McizINpuE3WmrWQHBQCmbc',
  );
  static const String _routesUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const String _placesAutocompleteUrl =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const String _placeDetailsUrl =
      'https://places.googleapis.com/v1/places/';

  MapService(this.dio);

  Future<List<PlaceSuggestionModel>> getPlaceSuggestions(
    String query,
    String sessionToken,
  ) async {
    try {
      final response = await dio.post(
        _placesAutocompleteUrl,
        options: Options(
          headers: {
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask':
                'suggestions.placePrediction.placeId,suggestions.placePrediction.text.text',
          },
        ),
        data: {
          'input': query,
          'languageCode': 'ar',
          'sessionToken': sessionToken,
          'locationRestriction': {
            'rectangle': {
              // أقصى جنوب غرب (SW)
              'low': {'latitude': 22.0, 'longitude': 25.0},
              // أقصى شمال شرق (NE)
              'high': {'latitude': 31.27, 'longitude': 34.1},
            },
          },
        },
      );

      if (response.statusCode == 200) {
        final suggestions = response.data['suggestions'] as List;
        return suggestions
            .map(
              (suggestion) => PlaceSuggestionModel(
                placeId: suggestion['placePrediction']['placeId'],
                description: suggestion['placePrediction']['text']['text'],
              ),
            )
            .toList();
      } else {
        throw Exception('Failed to fetch place suggestions');
      }
    } catch (e) {
      throw Exception('Error fetching place suggestions: $e');
    }
  }

  Future<LocationModel> getPlaceLocation(String placeId) async {
    try {
      final response = await dio.get(
        '$_placeDetailsUrl$placeId',
        options: Options(
          headers: {'X-Goog-Api-Key': _apiKey, 'X-Goog-FieldMask': 'location'},
        ),
      );

      if (response.statusCode == 200) {
        final location = response.data['location'];
        return LocationModel(
          latitude: location['latitude'],
          longitude: location['longitude'],
        );
      } else {
        throw Exception('Failed to fetch place details');
      }
    } catch (e) {
      throw Exception('Error fetching place details: $e');
    }
  }

  Future<RouteResultModel> getRouteBetweenLocations(
    LocationModel from,
    LocationModel to,
  ) async {
    try {
      final response = await dio.post(
        _routesUrl,
        data: {
          'origin': {
            'location': {
              'latLng': {
                'latitude': from.latitude,
                'longitude': from.longitude,
              },
            },
          },
          'destination': {
            'location': {
              'latLng': {'latitude': to.latitude, 'longitude': to.longitude},
            },
          },
          'travelMode': 'DRIVE',
          'routingPreference': 'TRAFFIC_AWARE',
        },
        options: Options(
          headers: {
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask':
                'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration',
          },
        ),
      );

      if (response.statusCode == 200) {
        log(response.data.toString());
        final routes = response.data['routes'] as List;
        if (routes.isEmpty) throw Exception('No routes found');

        final polyline = routes[0]['polyline']['encodedPolyline'];
        final distanceMeters = routes[0]['distanceMeters'] as int;
        final duration = routes[0]['duration'] as String;
        final points = _decodePolyline(polyline);
        final distanceKm = distanceMeters / 1000.0;
        return RouteResultModel(
          points: points,
          distanceKm: distanceKm,
          duration: formatDuration(duration),
        );
      } else {
        throw Exception(
          'Failed to fetch route: ${response.statusCode} - ${response.data['message'] ?? response.data}',
        );
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        throw Exception(
          'Routes API error: ${e.response!.data['message'] ?? e.message}',
        );
      } else {
        throw Exception('Network error fetching route: $e');
      }
    } catch (e) {
      throw Exception('Error fetching route: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  Future<EtaDistanceResult?> getEstimatedTimeOfArrival(
    LocationModel from,
    LocationModel to,
  ) async {
    try {
      final response = await dio.post(
        _routesUrl,
        data: {
          'origin': {
            'location': {
              'latLng': {
                'latitude': from.latitude,
                'longitude': from.longitude,
              },
            },
          },
          'destination': {
            'location': {
              'latLng': {'latitude': to.latitude, 'longitude': to.longitude},
            },
          },
          'travelMode': 'DRIVE',
          'routingPreference': 'TRAFFIC_AWARE',
        },
        options: Options(
          headers: {
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask':
                'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration',
          },
        ),
      );

      if (response.statusCode == 200) {
        log(response.data.toString());
        final routes = response.data['routes'] as List;
        if (routes.isEmpty) throw Exception('No routes found');

        final durationStr = routes[0]['duration'] as String;
        final distanceMeters = routes[0]['distanceMeters'] as int;

        final seconds = int.tryParse(
          durationStr.replaceAll(RegExp(r'[^0-9]'), ''),
        );

        if (seconds == null) {
          throw Exception('Invalid duration format: $durationStr');
        }

        return EtaDistanceResult(
          eta: Duration(seconds: seconds),
          distanceMeters: distanceMeters,
        );
      }
    } catch (e) {
      log('getEstimatedTimeOfArrival error: $e');
      return null;
    }
    return null;
  }
}
