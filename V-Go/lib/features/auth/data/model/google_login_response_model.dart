class GoogleLoginResponseModel {
  final String authUrl;
  final String state;
  final String? redirectUrl;

  GoogleLoginResponseModel({
    required this.authUrl,
    required this.state,
    required this.redirectUrl,
  });

  factory GoogleLoginResponseModel.fromJson(Map<String, dynamic> json) {
    return GoogleLoginResponseModel(
      authUrl: json['authUrl'],
      state: json['state'],
      redirectUrl: json['redirectUri'],
    );
  }
}
