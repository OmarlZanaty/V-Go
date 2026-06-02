class DriverStatusModel {
  final String driverId;
  final String driverGender;
  final bool isAvailable;
  final double lat;
  final double lng;

  DriverStatusModel({
    required this.driverId,
    required this.driverGender,
    required this.isAvailable,
    this.lat = 0.0,
    this.lng = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'driverGender': driverGender,
    'isAvailable': isAvailable,
    'latitude': lat,
    'longitude': lng,
  };
}
