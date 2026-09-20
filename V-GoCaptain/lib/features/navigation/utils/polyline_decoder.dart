import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decoder for Google's Encoded Polyline Algorithm Format. The Routes API returns
/// the route geometry as an encoded string; we expand it into LatLng vertices for
/// drawing and for on-route/deviation checks.
class PolylineDecoder {
  PolylineDecoder._();

  /// Decode [encoded] into its list of points. Returns an empty list for null or
  /// malformed input (never throws — a bad polyline must not crash navigation).
  static List<LatLng> decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];

    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    try {
      while (index < len) {
        int shift = 0;
        int result = 0;
        int b;
        // Latitude.
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < len);
        final int dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        lat += dLat;

        shift = 0;
        result = 0;
        // Longitude.
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < len);
        final int dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        lng += dLng;

        points.add(LatLng(lat / 1e5, lng / 1e5));
      }
    } catch (_) {
      // Truncated/garbled string — return whatever decoded cleanly so far.
      return points;
    }
    return points;
  }
}
