import 'dart:convert';

import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../model/login_response_model.dart';
import '../model/phone_login_response_model.dart';
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
  Future<bool> checkPhoneExists(String phone) async {
    final response = await _apiServices.get(
      EndPoint.phoneExists,
      queryParameters: {'phone': phone},
    );
    return response['exists'] == true;
  }

  @override
  Future<PhoneLoginResponseModel> phoneLogin({
    required String phone,
    required String password,
    required String fcmToken,
    required String deviceType,
  }) async {
    final response = await _apiServices.post(
      EndPoint.phoneLogin,
      data: {
        'phone': phone,
        'password': password,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
      },
    );
    return PhoneLoginResponseModel.fromJson(response['data']);
  }

  @override
  Future<PhoneLoginResponseModel> phoneRegisterDriver({
    required String phone,
    required String password,
    required String fullName,
    String? email,
    String? gender,
    String? nationalId,
    String? driverLicense,
    required int scooterType,
    String? scooterLicense,
    required String fcmToken,
    required String deviceType,
  }) async {
    final response = await _apiServices.post(
      EndPoint.phoneRegisterDriver,
      data: {
        'phone': phone,
        'password': password,
        'fullName': fullName,
        'email': email,
        'gender': gender,
        'nationalId': nationalId,
        'driverLicense': driverLicense,
        'scooterType': scooterType,
        'scooterLicense': scooterLicense,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
      },
    );
    return PhoneLoginResponseModel.fromJson(response['data']);
  }

  @override
  Future<int> phoneResetRequest({required String phone}) async {
    final response = await _apiServices.post(
      EndPoint.phoneResetRequest,
      data: {'phone': phone},
    );
    final data = response['data'];
    final seconds = data is Map ? data['cooldownSeconds'] : null;
    return seconds is num && seconds >= 0 ? seconds.toInt() : 60;
  }

  @override
  Future<String> phoneResetVerify({
    required String phone,
    required String code,
  }) async {
    final response = await _apiServices.post(
      EndPoint.phoneResetVerify,
      data: {'phone': phone, 'code': code},
    );
    final data = response['data'];
    final resetToken = data is Map ? data['resetToken'] : null;
    if (resetToken is! String || resetToken.trim().isEmpty) {
      throw 'فشل الحصول على رمز إعادة تعيين كلمة المرور، أعد المحاولة.';
    }
    return resetToken;
  }

  @override
  Future<void> phoneResetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _apiServices.post(
      EndPoint.phoneResetPassword,
      data: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
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

  @override
  Future<PhoneLoginResponseModel> googleTokenDriver({
    required String idToken,
    String? fullName,
    String? phone,
    String? gender,
    String? nationalId,
    String? driverLicense,
    int scooterType = 0,
    String? scooterLicense,
    required String fcmToken,
    required String deviceType,
  }) async {
    final response = await _apiServices.post(
      EndPoint.googleLoginDriverToken,
      data: {
        'idToken': idToken,
        'fullName': fullName,
        'phone': phone,
        'gender': gender,
        'nationalId': nationalId,
        'driverLicense': driverLicense,
        'scooterType': scooterType,
        'scooterLicense': scooterLicense,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
      },
    );
    return PhoneLoginResponseModel.fromJson(response['data']);
  }
}
