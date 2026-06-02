import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/model/location_model.dart';

class LocationService {
  /// this method is used to request location permission and return true if permission is granted
  Future<bool> requestLocationPermission() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      throw Exception('خطأ في طلب إذن الموقع: $e');
    }
  }

  /// this method is used to get current location
  Future<LocationModel> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('تم رفض إذن الموقع');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );

      return LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        accuracy: position.accuracy,
        speed: position.speed,
      );
    } catch (e) {
      throw Exception('خطأ في الحصول على الموقع الحالي: $e');
    }
  }

  /// this method is used to get address from coordinates
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // This method remains the same as it uses geocoding package
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        throw Exception('لم يتم العثور على عنوان للإحداثيات');
      }

      final placemark = placemarks.first;
      final components = <String>[];

      if (placemark.thoroughfare != null &&
          placemark.thoroughfare!.isNotEmpty) {
        components.add(placemark.thoroughfare!);
        if (placemark.subThoroughfare != null &&
            placemark.subThoroughfare!.isNotEmpty) {
          components.insert(0, placemark.subThoroughfare!);
        }
      }

      if (placemark.locality != null && placemark.locality!.isNotEmpty) {
        components.add(placemark.locality!);
      }

      if (placemark.administrativeArea != null &&
          placemark.administrativeArea!.isNotEmpty) {
        components.add(placemark.administrativeArea!);
      }

      if (components.isEmpty) {
        return 'الموقع عند (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
      }

      return components.join('، ').trim();
    } catch (e) {
      throw Exception('خطأ في الحصول على العنوان من الإحداثيات: $e');
    }
  }

  /// this method is used to get location stream
  Stream<LocationModel> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        distanceFilter: 10,
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    ).map(
      (position) => LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        accuracy: position.accuracy,
        speed: position.speed,
      ),
    );
  }
}
