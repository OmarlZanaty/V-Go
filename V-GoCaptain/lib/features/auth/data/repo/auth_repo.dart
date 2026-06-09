import '../model/login_response_model.dart';
import '../model/phone_login_response_model.dart';
import '../model/register_request_model.dart';
import '../model/reset_password_request_model.dart';

abstract class AuthRepo {
  Future<LoginResponseModel> login({
    required String email,
    required String password,
    required String fcmToken,
    required String deviceType,
  });

  Future<PhoneLoginResponseModel> phoneLogin({
    required String idToken,
    required String fcmToken,
    required String deviceType,
  });

  Future<PhoneLoginResponseModel> phoneRegisterDriver({
    required String idToken,
    required String fullName,
    String? email,
    String? gender,
    String? nationalId,
    String? driverLicense,
    required int scooterType,
    String? scooterLicense,
    required String fcmToken,
    required String deviceType,
  });


  Future<String> register(RegisterRequestModel model);

  Future<void> verifyOtp(String email, String otp, String type);

  Future<String> resendOtp(String email, String otpType);

  Future<String> forgetPassword(String email);

  Future<String> resetPassword(ResetPasswordRequestModel model);

  Future<String> changePassword(
    String email,
    String oldPassword,
    String newPassword,
  );

  Future<void> logout({required String refreshToken});

  // Google Sign-In (native token)
  Future<PhoneLoginResponseModel> googleTokenDriver({
    required String idToken,
    String? fullName,
    String? gender,
    String? nationalId,
    String? driverLicense,
    int scooterType,
    String? scooterLicense,
    required String fcmToken,
    required String deviceType,
  });
}
