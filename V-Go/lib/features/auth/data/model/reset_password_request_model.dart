class ResetPasswordRequestModel {
  final String newPassword;
  final String email;

  ResetPasswordRequestModel({
    required this.newPassword,
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'newPassword': newPassword,
      'email': email,
    };
  }
}