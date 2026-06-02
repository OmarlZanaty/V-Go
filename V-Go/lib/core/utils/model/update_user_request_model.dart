import 'package:dio/dio.dart';

class UpdateUserRequestModel {
  final String? name;
  final String? phoneNumber;
  final String? gender;
  final String? nationalId;
  final String? license;
  final String? scooterLicense;
  final int? scooterType;
  final MultipartFile? profilePicture;

  UpdateUserRequestModel({
    this.name,
    this.phoneNumber,
    this.gender,
    this.nationalId,
    this.license,
    this.scooterLicense,
    this.scooterType,
    this.profilePicture,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'Name': name,
      if (phoneNumber != null) 'PhoneNumber': phoneNumber,
      if (gender != null) 'Gender': gender,
      if (nationalId != null) 'NationalId': nationalId,
      if (license != null) 'License': license,
      if (scooterLicense != null) 'ScooterLicense': scooterLicense,
      if (scooterType != null) 'ScooterType': scooterType,
      if (profilePicture != null) 'ProfilePicture': profilePicture,
    };
  }
}
