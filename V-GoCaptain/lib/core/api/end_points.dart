import '../config/app_config.dart';

/// Endpoints used by the Captain (driver) app. They target the same shared
/// backend as the rider app.
abstract class EndPoint {
  static String get baseUrl => AppConfig.apiBaseUrl;

  // Auth
  static const String login = 'Auth/login';
  static const String register = 'Auth/register';
  static const String logout = 'Auth/logout';
  static const String confirmOtp = 'Auth/confirmOtp';
  static const String resendOtp = 'Auth/resendotp';
  static const String newRefreshToken = 'Auth/newrefreshtoken';
  static const String forgotPassword = 'Auth/forgotPassword';
  static const String resetPassword = 'Auth/resetPassword';
  static const String changePassword = 'Auth/changePassword';

  // Driver
  static const String availableDrivers = 'Driver/availableDriversFromCache';
  static String getDriverById(String userId) => 'Driver/driver/$userId';

  // Trips
  static const String allPendingTrips = 'Trip/GetAllPendingTrips';
  static const String currentTrips = 'Trip/cuurentTrips';
  static String getTripsByUserId(String userId) => 'Trip/tripByUserId/$userId';
  static String getTripById(String tripId) => 'Trip/GetTripById/$tripId';

  // Notifications
  static const String getNotifications = 'Notification/GetAll';
}
