class AppConfig {
  AppConfig._();

  static const String _defaultApiBaseUrl =
      'https://52.57.40.64.sslip.io/api/';
  static const String _defaultSignalRBaseUrl =
      'https://52.57.40.64.sslip.io';

  /// Base URL for REST APIs. Override with:
  /// `--dart-define=API_BASE_URL=https://your-domain/api/`
  static String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: _defaultApiBaseUrl,
      );

  /// Base URL for SignalR hub endpoints. Override with:
  /// `--dart-define=SIGNALR_BASE_URL=https://your-domain`
  static String get signalRBaseUrl => const String.fromEnvironment(
        'SIGNALR_BASE_URL',
        defaultValue: _defaultSignalRBaseUrl,
      );

  /// Google API key used for the Routes API v2 (server-side HTTP routing).
  /// Override with `--dart-define=ROUTES_API_KEY=...`.
  ///
  /// This defaults to the same Android-restricted key the Maps SDK uses. An
  /// Android-restricted key DOES authorize plain HTTP calls as long as the
  /// request carries the app's package + signing-cert SHA-1 (see
  /// [androidPackage] / [androidCertSha1] below), which is exactly what
  /// [RoutesApiService] sends. The key must also have the **Routes API** enabled
  /// and allowed in its API restrictions (Google Cloud Console).
  static String get routesApiKey => const String.fromEnvironment(
        'ROUTES_API_KEY',
        // Shared with the client app (V-Go map_service.dart). This key has the
        // Routes API enabled; the previous captain-only key returned 403
        // PERMISSION_DENIED because Routes API wasn't authorized for it.
        defaultValue: 'AIzaSyDpdwRptK8i3McizINpuE3WmrWQHBQCmbc',
      );

  /// App package + signing-cert SHA-1, sent as `X-Android-Package` /
  /// `X-Android-Cert` so an Android-restricted API key accepts our server-style
  /// Routes HTTP calls (the Maps SDK sends the same credentials natively).
  ///
  /// SHA-1 must be UPPERCASE hex with NO colons. Defaults match the debug build;
  /// for a release build pass the release keystore's SHA-1 via
  /// `--dart-define=ANDROID_CERT_SHA1=...` (and ANDROID_PACKAGE if it differs).
  static String get androidPackage => const String.fromEnvironment(
        'ANDROID_PACKAGE',
        defaultValue: 'com.scooterapp.vgo.v_go_captain',
      );

  static String get androidCertSha1 => const String.fromEnvironment(
        'ANDROID_CERT_SHA1',
        defaultValue: '1A9FD10BE3B899476659BC505C8F01B54F2C7E86',
      );

  static String hubUrl(String hubPath) {
    final base = signalRBaseUrl.endsWith('/')
        ? signalRBaseUrl.substring(0, signalRBaseUrl.length - 1)
        : signalRBaseUrl;
    final path = hubPath.startsWith('/') ? hubPath.substring(1) : hubPath;
    return '$base/$path';
  }
}
