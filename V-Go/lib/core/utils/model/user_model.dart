import 'location_model.dart';

class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? role;
  final String? phoneNumber;
  final String? gender;
  final String? nationalId;
  final String? license;
  final String? scooterLicense;
  final int? scooterType;
  final String? profilePicture;
  final LocationModel? location;
  final int? tripCount;
  final ProfitModel? driverProfit;
  final num? rate;
  final bool? isBlocked;
  final bool? isAvailable;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.role,
    this.phoneNumber,
    this.gender,
    this.nationalId,
    this.license,
    this.scooterLicense,
    this.scooterType,
    this.profilePicture,
    this.tripCount,
    this.driverProfit,
    this.isBlocked,
    this.location,
    this.isAvailable,
    this.rate = 0.0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      role: (json['roles'] != null && (json['roles'] as List).isNotEmpty)
          ? json['roles'][0] as String?
          : null,
      phoneNumber: json['phoneNumber'] as String?,
      gender: json['gender'] as String?,
      nationalId: json['nationalId'] as String?,
      license: json['license'] as String?,
      scooterLicense: json['scooterLicense'] as String?,
      scooterType: json['scooterType'] as int?,
      profilePicture: json['profilePicture'] as String?,
      tripCount: json['tripCount'] as int?,
      driverProfit: json['profit'] != null
          ? ProfitModel.fromJson(json['profit'] as Map<String, dynamic>)
          : null,
      isBlocked: json['isBlocked'] as bool?,
      rate: json['rate'] as num?,
      isAvailable: json['isAvailable'] as bool?,
      location: json['location'] != null
          ? LocationModel.fromJson(json['location'] as Map<String, dynamic>)
          : null,
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phoneNumber,
    String? gender,
    String? nationalId,
    String? license,
    String? scooterLicense,
    int? scooterType,
    String? profilePicture,
    LocationModel? location,
    int? tripCount,
    ProfitModel? driverProfit,
    bool? isBlocked,
    bool? isAvailable,
    num? rate,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      nationalId: nationalId ?? this.nationalId,
      license: license ?? this.license,
      scooterLicense: scooterLicense ?? this.scooterLicense,
      scooterType: scooterType ?? this.scooterType,
      profilePicture: profilePicture ?? this.profilePicture,
      location: location ?? this.location,
      tripCount: tripCount ?? this.tripCount,
      driverProfit: driverProfit ?? this.driverProfit,
      isBlocked: isBlocked ?? this.isBlocked,
      isAvailable: isAvailable ?? this.isAvailable,
      rate: rate ?? this.rate,
    );
  }
}

class ProfitModel {
  final num dailyProfit;
  final num weeklyProfit;
  final num monthlyProfit;
  final num allTimeProfit;

  ProfitModel({
    required this.dailyProfit,
    required this.weeklyProfit,
    required this.monthlyProfit,
    required this.allTimeProfit,
  });

  factory ProfitModel.fromJson(Map<String, dynamic> json) {
    return ProfitModel(
      dailyProfit: json['DailyProfit'] as num,
      weeklyProfit: json['WeeklyProfit'] as num,
      monthlyProfit: json['MonthlyProfit'] as num,
      allTimeProfit: json['AllTimeProfit'] as num,
    );
  }
}
