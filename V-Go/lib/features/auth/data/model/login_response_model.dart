import '../../../../core/helpers/get_gender.dart';

class LoginResponseModel {
  final String userId;
  final String token;
  final String refreshToken;
  final String gender;
  final String role;
  final bool genderConfirmed;

  LoginResponseModel({
    required this.token,
    required this.userId,
    required this.refreshToken,
    required this.role,
    required this.gender,
    this.genderConfirmed = true,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      userId: json['userId'] as String,
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
      role: json['roles'][0] as String,
      gender: json['gender'] as String,
      genderConfirmed: parseGenderConfirmed(json),
    );
  }
}
