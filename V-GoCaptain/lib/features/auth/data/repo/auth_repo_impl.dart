import 'dart:convert';

import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../model/login_response_model.dart';
import '../model/register_request_model.dart';
import '../model/reset_password_request_model.dart';
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
  Future<String> register(RegisterRequestModel model) async {
    final response = await _apiServices.post(
      EndPoint.register,
      data: model.toJson(),
      isFormData: true,
    );
    return response['message'];
  }

  @override
  Future<void> verifyOtp(String email, String otp, String type) async {
    await _apiServices.post(
      EndPoint.confirmOtp,
      queryParameters: {'otp': otp, 'email': email, 'type': type},
    );
  }

  @override
  Future<String> resendOtp(String email, String otpType) async {
    final response = await _apiServices.post(
      EndPoint.resendOtp,
      data: jsonEncode(email),
      queryParameters: {'otpType': otpType},
    );
    return response['message'];
  }

  @override
  Future<String> forgetPassword(String email) async {
    final response = await _apiServices.post(
      EndPoint.forgotPassword,
      data: jsonEncode(email),
    );
    return response.toString();
  }

  @override
  Future<String> resetPassword(ResetPasswordRequestModel model) async {
    final response = await _apiServices.post(
      EndPoint.resetPassword,
      data: model.toJson(),
    );
    return response.toString();
  }

  @override
  Future<String> changePassword(
    String email,
    String oldPassword,
    String newPassword,
  ) async {
    final response = await _apiServices.post(
      EndPoint.changePassword,
      data: jsonEncode({
        'email': email,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );
    return response.toString();
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    await _apiServices.post(
      EndPoint.logout,
      headers: {'refreshToken': refreshToken},
    );
  }
}
