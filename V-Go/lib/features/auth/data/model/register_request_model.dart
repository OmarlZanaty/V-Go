import 'package:dio/dio.dart';

class RegisterRequestModel {
  final String fullName;
  final String email;
  final String phone;
  final String gender;
  final String role;
  final String password;
  final String confirmPassword;
  final String? nationalId;
  final String? driverLicense;
  final String? scooterLicense;
  final String? fcmToken;
  final String? deviceType;
  final int? scooterType;
  final MultipartFile? imageProfile;

  RegisterRequestModel({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.role,
    required this.password,
    required this.confirmPassword,
    this.nationalId,
    this.driverLicense,
    this.scooterLicense,
    this.scooterType,
    this.imageProfile,
    this.fcmToken,
    this.deviceType,
  });

  Map<String, dynamic> toJson() {
    return {
      'FullName': fullName,
      'Email': email,
      'Phone': phone,
      'Gender': gender,
      'Role': role,
      'Password': password,
      'ConfirmPassword': confirmPassword,
      'NationalId': nationalId,
      'DriverLicense': driverLicense,
      'ScoterLicense': scooterLicense,
      'ScoterType': scooterType,
      'Photo': imageProfile,
      'FCMToken': fcmToken,
      'DeviceType': deviceType,
    };
  }
}
