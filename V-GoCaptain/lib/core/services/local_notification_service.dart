import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows heads-up local notifications on a dedicated high-importance channel.
/// Used to surface FCM messages while the app is in the foreground.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService _instance = LocalNotificationService._();
  factory LocalNotificationService() => _instance;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// High-importance channel for new-trip alerts (sound + vibration + heads-up).
  /// The id matches `default_notification_channel_id` in AndroidManifest so that
  /// background/terminated FCM notifications land on the same channel.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'trip_offers',
    'عروض الرحلات',
    description: 'إشعارات الرحلات الجديدة وتحديثات الحالة',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) {},
    );

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    // Android 13+ runtime permission.
    await androidImpl?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Unique id so multiple alerts stack instead of replacing each other.
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _plugin.show(id, title, body, details);
  }
}
