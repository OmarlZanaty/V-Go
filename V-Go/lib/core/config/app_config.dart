class AppConfig {
  AppConfig._();

  static const String _defaultApiBaseUrl =
      'https://vgo-api-792221536894.europe-west1.run.app/api/';
  static const String _defaultSignalRBaseUrl =
      'https://vgo-api-792221536894.europe-west1.run.app';

  /// Base URL for REST APIs. Override with:
  /// `--dart-define=API_BASE_URL=https://your-domain/api/`
  static String get apiBaseUrl =>
      const String.fromEnvironment('API_BASE_URL', defaultValue: _defaultApiBaseUrl);

  /// Base URL for SignalR hub endpoints. Override with:
  /// `--dart-define=SIGNALR_BASE_URL=https://your-domain`
  static String get signalRBaseUrl => const String.fromEnvironment(
        'SIGNALR_BASE_URL',
        defaultValue: _defaultSignalRBaseUrl,
      );

  static String hubUrl(String hubPath) {
    final base = signalRBaseUrl.endsWith('/')
        ? signalRBaseUrl.substring(0, signalRBaseUrl.length - 1)
        : signalRBaseUrl;
    final path = hubPath.startsWith('/') ? hubPath.substring(1) : hubPath;
    return '$base/$path';
  }
}

