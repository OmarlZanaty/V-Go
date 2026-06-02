class TripApprovedForClientModel {
  final String tripId;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String? driverImageUrl;
  final String status;
  final num? driverRate;
  final DriverLocation? driverLocation;
  final String scooterType;
  final String? scooterLicense;

  TripApprovedForClientModel({
    required this.tripId,
    required this.driverId,
    required this.status,
    required this.driverName,
    required this.driverPhone,
    required this.driverImageUrl,
    required this.driverLocation,
    required this.scooterType,
    this.scooterLicense,
    this.driverRate = 0.0,
  });

  factory TripApprovedForClientModel.fromJson(Map<String, dynamic> json) {
    return TripApprovedForClientModel(
      tripId: json['tripId'],
      driverId: json['driverId'],
      status: json['status'],
      driverName: json['driverName'],
      driverPhone: json['driverPhone'],
      driverImageUrl: json['driverPhoto'],
      driverLocation: DriverLocation.fromJson(json['driverLocation']),
      driverRate: json['driverRate'],
      scooterType: json['scooterType'],
      scooterLicense: json['scooterLicense'],
    );
  }
}

class DriverLocation {
  final String lat;
  final String lng;
  DriverLocation({required this.lat, required this.lng});

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(lat: json['lat'], lng: json['lng']);
  }
}
