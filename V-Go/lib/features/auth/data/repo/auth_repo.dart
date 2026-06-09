import '../model/check_state_response_model.dart';
import '../model/google_login_response_model.dart';
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
  Future<PhoneLoginResponseModel> phoneRegister({
    required String idToken,
    required String fullName,
    String? email,
    String? gender,
    required String fcmToken,
    required String deviceType,
  });
  Future<GoogleLoginResponseModel> googleLogin();
  Future<PhoneLoginResponseModel> googleTokenLogin({
    required String idToken,
    String? fullName,
    String? phone,
    String? gender,
    String? profilePicture,
    required String fcmToken,
    required String deviceType,
  });
  Future<String> register(RegisterRequestModel registerRequestModel);
  Future<CheckStateResponseModel> checkState({required String state});
  Future<String> forgetPassword(String email);
  Future<void> verifyEmailOtp(String email, String otp, String type);
  Future<String> resendOtp(String email, String otpType);
  Future<String> resetPassword(
    ResetPasswordRequestModel resetPasswordRequestModel,
  );
  Future<String> changePassword(
    String email,
    String oldPassword,
    String newPassword,
  );
  Future<void> logout({required String refreshToken});
}
