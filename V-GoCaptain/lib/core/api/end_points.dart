import '../config/app_config.dart';

/// Endpoints used by the Captain (driver) app. They target the same shared
/// backend as the rider app.
abstract class EndPoint {
  static String get baseUrl => AppConfig.apiBaseUrl;

  // Auth
  static const String login = 'Auth/login';
  static const String phoneLogin = 'Auth/phone-login-driver';         // Firebase phone auth
  static const String phoneRegisterDriver = 'Auth/phone-register-driver'; // Firebase phone auth
  static const String register = 'Auth/register';
  static const String logout = 'Auth/logout';
  static const String confirmOtp = 'Auth/confirmOtp';
  static const String resendOtp = 'Auth/resendotp';
  static const String newRefreshToken = 'Auth/newrefreshtoken';
  static const String forgotPassword = 'Auth/forgotPassword';
  static const String resetPassword = 'Auth/resetPassword';
  static const String changePassword = 'Auth/changePassword';
  static const String googleLoginDriverToken = 'Auth/google-login-driver-token';

  // Driver
  static const String availableDrivers = 'Driver/availableDriversFromCache';
  static String getDriverById(String userId) => 'Driver/driver/$userId';
  static const String sendAlert = 'Driver/sendAlert';

  // Trips
  static const String allPendingTrips = 'Trip/GetAllPendingTrips';
  static const String currentTrips = 'Trip/currentTrips';
  static String getTripsByUserId(String userId) => 'Trip/tripByUserId/$userId';
  static String getTripById(String tripId) => 'Trip/GetTripById/$tripId';

  // Notifications
  static const String getNotifications = 'Notification/GetAll';

  // Profile / ratings
  static String getDriverProfile(String userId) => 'Driver/driver/$userId';
  static String getUserRates(String userId) => 'Rate/userRates/$userId';

  // Support (in-app report -> support chat)
  static const String createSupportChat = 'Chat/createSupportChat';
  static const String sendSupportMessage = 'Message/sendSupportMessage';
}
