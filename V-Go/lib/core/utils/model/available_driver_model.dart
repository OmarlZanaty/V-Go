class AvailableDriverModel {
  final String driverId;
  final String driverName;
  final bool isAvailable;
  final String driverGender;
  final String? profilePhoto;

  AvailableDriverModel({
    required this.driverId,
    required this.driverName,
    required this.isAvailable,
    required this.driverGender,
    this.profilePhoto,
  });

  factory AvailableDriverModel.fromJson(Map<String, dynamic> json) {
    return AvailableDriverModel(
      driverId: json['driverId'],
      driverName: json['driverName'],
      isAvailable: json['isAvailable'],
      driverGender: json['driverGender'],
      profilePhoto: json['profilePhoto'],
    );
  }
}