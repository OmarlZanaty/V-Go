/// Response of `Auth/phone-login`. For an existing user the session fields are
/// present; for a new (unregistered) verified phone, [isNewUser] is true and
/// [phone] carries the verified number to continue sign-up.
class PhoneLoginResponseModel {
  final bool isNewUser;
  final String? phone;
  final String? userId;
  final String? token;
  final String? refreshToken;
  final String? gender;
  final String? role;
  final String? name;
  final String? profilePicture;

  PhoneLoginResponseModel({
    required this.isNewUser,
    this.phone,
    this.userId,
    this.token,
    this.refreshToken,
    this.gender,
    this.role,
    this.name,
    this.profilePicture,
  });

  factory PhoneLoginResponseModel.fromJson(Map<String, dynamic> json) {
    final roles = json['roles'];
    return PhoneLoginResponseModel(
      isNewUser: json['isNewUser'] == true,
      phone: json['phone'] as String?,
      userId: json['userId'] as String?,
      token: json['token'] as String?,
      refreshToken: json['refreshToken'] as String?,
      gender: json['gender'] as String?,
      role: (roles is List && roles.isNotEmpty) ? roles.first as String : null,
      name: json['name'] as String?,
      profilePicture: json['profilePicture'] as String?,
    );
  }
}
