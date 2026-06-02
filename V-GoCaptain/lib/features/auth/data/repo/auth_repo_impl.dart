import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../model/login_response_model.dart';
import 'auth_repo.dart';

class AuthRepoImpl implements AuthRepo {
  final ApiServices _apiServices;
  AuthRepoImpl({required ApiServices apiServices}) : _apiServices = apiServices;

  @override
  Future<LoginResponseModel> login({
    required String email,
    required String password,
    required String fcmToken,
    required String deviceType,
  }) async {
    final response = await _apiServices.post(
      EndPoint.login,
      data: {
        'email': email,
        'password': password,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
      },
    );
    return LoginResponseModel.fromJson(response['data']);
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    await _apiServices.post(
      EndPoint.logout,
      headers: {'refreshToken': refreshToken},
    );
  }
}
