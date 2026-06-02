class LoginResponseModel {
  final String userId;
  final String token;
  final String refreshToken;
  final String gender;
  final String role;
  final String name;
  final String profilePicture;

  LoginResponseModel({
    required this.token,
    required this.userId,
    required this.refreshToken,
    required this.role,
    required this.gender,
    required this.name,
    required this.profilePicture,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final roles = json['roles'];
    final firstRole =
        (roles is List && roles.isNotEmpty) ? roles.first.toString() : '';
    return LoginResponseModel(
      userId: json['userId']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      role: firstRole,
      gender: json['gender']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      profilePicture: json['profilePicture']?.toString() ?? '',
    );
  }
}
