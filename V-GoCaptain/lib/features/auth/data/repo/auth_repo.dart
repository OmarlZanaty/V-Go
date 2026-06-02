import '../model/login_response_model.dart';

abstract class AuthRepo {
  Future<LoginResponseModel> login({
    required String email,
    required String password,
    required String fcmToken,
    required String deviceType,
  });

  Future<void> logout({required String refreshToken});
}
