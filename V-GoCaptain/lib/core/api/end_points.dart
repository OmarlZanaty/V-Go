import '../config/app_config.dart';

/// Endpoints used by the Captain (driver) app. They target the same shared
/// backend as the rider app.
abstract class EndPoint {
  static String get baseUrl => AppConfig.apiBaseUrl;

  // Auth
  static const String login = 'Auth/login';
  static const String phoneLogin =
      'Auth/phone-login-driver'; // phone + password
  static const String phoneRegisterDriver =
      'Auth/phone-register-driver'; // phone + password
  static const String phoneExists =
      'Auth/phone-exists'; // new-vs-returning check
  static const String phoneResetPassword =
      'Auth/phone-reset-password'; // forgot password (OTP)
  static const String register = 'Auth/register';
  static const String logout = 'Auth/logout';
  static const String confirmOtp = 'Auth/confirmOtp';
  static const String resendOtp = 'Auth/resendotp';
  static const String newRefreshToken = 'Auth/newrefreshtoken';
  static const String forgotPassword = 'Auth/forgotPassword';
  static const String resetPassword = 'Auth/resetPassword';
  static const String changePassword = 'Auth/changePassword';
  static const String googleLoginDriverToken = 'Auth/google-login-driver-token';
  static const String setPhone = 'Auth/set-phone';

  // Driver
  static const String availableDrivers = 'Driver/availableDriversFromCache';
  static String getDriverById(String userId) => 'Driver/driver/$userId';
  static const String sendAlert = 'Driver/sendAlert';

  // Trips
  static const String allPendingTrips = 'Trip/GetAllPendingTrips';
  static const String currentTrips = 'Trip/currentTrips';
  static String getTripsByUserId(String userId) => 'Trip/tripByUserId/$userId';
  static String getTripById(String tripId) => 'Trip/GetTripById/$tripId';

  // Payment — fetching status also triggers a server-side reconcile with Paymob,
  // settling a card payment whose webhook was missed.
  static String paymentStatus(String tripId) => 'Payment/status/$tripId';
  static const String paymentConfirmCallback = 'Payment/confirm-callback';

  // Driver finance
  static const String driverFinanceSummary = 'DriverFinance/me/summary';
  static const String driverFinanceLedger = 'DriverFinance/me/ledger';
  static const String driverFinanceEligibility = 'DriverFinance/me/eligibility';
  static const String driverFinancePayoutAccount =
      'DriverFinance/me/payout-account';
  static const String driverFinanceSettle = 'DriverFinance/me/settle';
  static String driverFinanceSettleStatus(String paymentId) =>
      'DriverFinance/me/settle/$paymentId';

  // Driver verification
  static const String driverVerificationMe = 'DriverVerification/me';
  static const String driverVerificationDocuments =
      'DriverVerification/me/documents';

  // Notifications
  static const String getNotifications = 'Notification/GetAll';

  // Profile / ratings
  static String getDriverProfile(String userId) => 'Driver/driver/$userId';
  static String updateUser(String userId) => 'User/update/$userId';
  static String getUserRates(String userId) => 'Rate/userRates/$userId';

  // Support (in-app report -> support chat)
  static const String createSupportChat = 'Chat/createSupportChat';
  static const String sendSupportMessage = 'Message/sendSupportMessage';
}
