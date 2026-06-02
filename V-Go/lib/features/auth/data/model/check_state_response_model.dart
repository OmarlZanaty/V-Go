class CheckStateResponseModel {
  final String status;
  final UserModel? user;

  CheckStateResponseModel({required this.status, this.user});

  factory CheckStateResponseModel.fromJson(Map<String, dynamic> json) =>
      CheckStateResponseModel(
        status: json['status'] ?? '',
        user: json['user'] != null
            ? UserModel.fromJson(Map<String, dynamic>.from(json['user']))
            : null,
      );
}

class UserModel {
  final String userId;
  final String name;
  final String roles;
  final String gender;
  final String token;
  final String refreshToken;

  UserModel({
    required this.userId,
    required this.name,
    required this.roles,
    required this.gender,
    required this.token,
    required this.refreshToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    userId: json['userId'],
    name: json['name'],
    gender: json['gender'],
    roles: json['roles'][0],
    token: json['token'],
    refreshToken: json['refreshToken'],
  );
}
