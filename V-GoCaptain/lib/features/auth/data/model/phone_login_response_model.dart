/// Response of `Auth/phone-login` / `Auth/phone-register-driver`. For an existing
/// user the session fields are present; for a new verified phone, [isNewUser] is
/// true and [phone] carries the verified number to continue sign-up.
class PhoneLoginResponseModel {
  final bool isNewUser;
  final String? phone;
  final String userId;
  final String token;
  final String refreshToken;
  final String role;
  final String name;
  final String gender;
  final String profilePicture;

  PhoneLoginResponseModel({
    required this.isNewUser,
    this.phone,
    this.userId = '',
    this.token = '',
    this.refreshToken = '',
    this.role = '',
    this.name = '',
    this.gender = '',
    this.profilePicture = '',
  });

  factory PhoneLoginResponseModel.fromJson(Map<String, dynamic> json) {
    final roles = json['roles'];
    return PhoneLoginResponseModel(
      isNewUser: json['isNewUser'] == true,
      phone: json['phone']?.toString(),
      userId: json['userId']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      role: (roles is List && roles.isNotEmpty) ? roles.first.toString() : '',
      name: json['name']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      profilePicture: json['profilePicture']?.toString() ?? '',
    );
  }
}
