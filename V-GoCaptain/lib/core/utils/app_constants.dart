abstract class AppConstants {
  // Secure storage / prefs keys
  static const String token = "token";
  static const String refreshToken = "refreshToken";
  static const String role = "role";
  static const String gender = "gender";
  static const String userId = "userId";
  static const String userName = "userName";
  static const String profileImage = "profileImage";
  static const String fcmToken = "fcmToken";

  // Settings: when true the in-app notifications feature is muted.
  static const String notificationsMuted = "notificationsMuted";

  // In-memory session values
  static String kUserId = "";
  static String kToken = "";
  static String kRole = "";
  static String kUserName = "";
  static String kProfileImage = "";

  // This is the Captain (driver) app — only drivers may use it.
  static const String driverRole = "Driver";

  // Device type sent to the backend on login.
  static const String deviceType = "Android";

  /// The company's public Instagram page (client-supplied, 2026-11-02).
  static const String kInstagramUrl = "https://www.instagram.com/v.go.eg";
}

enum CaptainStatus { offline, online, onTrip }

enum TripStage { accepted, arrived, inProgress, completed }
