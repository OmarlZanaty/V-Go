import '../config/app_config.dart';

abstract class EndPoint {
  // Base URL
  static String get baseUrl => AppConfig.apiBaseUrl;

  // Auth Endpoints
  static const String login = 'Auth/login';
  static const String phoneLogin = 'Auth/phone-login';       // Firebase phone auth
  static const String phoneRegister = 'Auth/phone-register'; // Firebase phone auth
  static const String register = 'Auth/register';
  static const String logout = 'Auth/logout';
  static const String confirmOtp = 'Auth/confirmOtp';
  static const String resendOtp = 'Auth/resendotp';
  static const String newRefreshToken = 'Auth/newrefreshtoken';
  static const String forgotPassword = 'Auth/forgotPassword';
  static const String resetPassword = 'Auth/resetPassword';
  static const String changePassword = 'Auth/changePassword';
  static const String googleLogin = 'Auth/mobile/google-login';
  static String checkState(String state) => 'Auth/mobile/check-auth/$state';
  static const String googleLoginToken = 'Auth/google-login-token';

  // User Endpoints
  static const String allUsers = 'User/allUsers';
  static const String deleteUser = 'User/remove';
  static const String blockUser = 'User/block';
  static const String unBlockUser = 'User/unblock';
  static String getUserById(String userId) => 'User/user/$userId';
  static String updateUser(String userId) => 'User/updateUserForAdmin/$userId';

  // Driver Endpoints
  static const String availableDrivers = 'Driver/availableDriversFromCache';
  static String getDriverById(String userId) => 'Driver/driver/$userId';

  // Trip Endpoints
  static const String allTrips = 'Trip/GetAllTripsByStatus';
  static const String allPendingTrips = 'Trip/GetAllPendingTrips';
  static const String getCurrentTrips = 'Trip/currentTrips';
  static String getTripsByUserId(String userId) => 'Trip/tripByUserId/$userId';
  static String getTripById(String tripId) => 'Trip/GetTripById/$tripId';

  // Pricing Endpoints
  static const String pricingRule = 'PricingRule';
  static const String getPricePerKillo = 'PricingRule/getPricePerKillo';
  static const String driverCommission = 'PricingRule/setDriverCommission';

  // Statistics Endpoints
  static const String numbersStatistics = 'Statistics/numbersStatistics';
  static const String accountantStatistics =
      'Statistics/GetAccountantStatistics';

  // Notification Endpoints
  static const String getNotifications = 'Notification/GetAll';

  // Chat & Message Endpoints
  static const String getChatMessages = 'Message/supportChatMessages';
  static const String getDispatcherChats = 'Chat/allDispatcherSupportChats';

  // Expense Endpoints
  static const String addExpense = 'Expense/AddExpens';
  static String deleteExpense(String expenseId) =>
      'Expense/DeleteExpense/$expenseId';
  static String allExpenses = 'Expense/GetAllExpenses';

  // Payment Endpoints
  static const String createPaymentIntent = 'Payment/createIntent';
  // Visa pre-authorization (Auth & Capture): creates a hold instead of an immediate
  // sale. Returns the same unified-checkout payload as createIntent. Capture/void
  // happen server-side on ride completion/cancellation.
  static const String initiatePreAuth = 'Payment/initiate-preauth';
}
