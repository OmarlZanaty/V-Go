class DriverAlertModel {
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String? driverProfilePicture;
  final double latitude;
  final double longitude;
  final DateTime alerttime;

  DriverAlertModel({
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.latitude,
    required this.longitude,
    required this.alerttime,
    this.driverProfilePicture,
  });

  factory DriverAlertModel.fromJson(Map<String, dynamic> json) {
    return DriverAlertModel(
      driverId: json['driverId'] as String,
      driverName: json['driverName'] as String,
      driverPhone: json['driverPhone'] as String,
      driverProfilePicture: json['driverProfilePicture'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      alerttime: DateTime.parse(json['alerttime'] as String),
    );
  }
}
