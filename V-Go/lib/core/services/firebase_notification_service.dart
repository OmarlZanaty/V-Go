import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../cache/cache_helper.dart';
import '../helpers/navigation_handler.dart';
import '../routing/routes.dart';
import '../utils/app_constants.dart';
import 'flutter_local_notification_service.dart';
import '../../firebase_options.dart';

/// A service for handling Firebase Cloud Messaging (FCM) notifications.
class FirebaseNotificationService {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();

  factory FirebaseNotificationService() => _instance;

  FirebaseNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Initialize the notification service.
  Future<void> initialize() async {
    try {
      await _initializeFirebaseMessaging();

      final String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await CacheHelper.setData(key: AppConstants.fcmToken, value: token);
      } else {
        log('Failed to get FCM token');
      }

      log('NotificationService initialized successfully');
      await handleInitialMessage();
    } catch (e) {
      log('Error initializing NotificationService: $e');
    }
  }

  Future<void> handleInitialMessage() async {
    final RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      log('Received initial message:-----------');
      _navigateToScreen(initialMessage);
    }
  }

  void _navigateToScreen(RemoteMessage message) {
    if (message.data.isNotEmpty && message.data['DriverId'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NavigationHandler.navigatorKey.currentState?.pushNamed(
          Routes.userDetailsViewRoute,
          arguments: {'userId': message.data['DriverId'], 'isDriver': true},
        );
      });
    }
  }

  /// Initialize Firebase Messaging.
  Future<void> _initializeFirebaseMessaging() async {
    await _firebaseMessaging.requestPermission();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  /// Handle foreground messages.
  void _handleForegroundMessage(RemoteMessage message) {
    log('Message data: ${message.data}');

    if (message.notification?.title != null &&
        message.notification?.title != 'رسالة جديدة') {
      LocalNotificationService().showNotification(
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
      );
    }
  }

  /// Handle background messages when the app is opened from a notification.
  void _handleBackgroundMessage(RemoteMessage message) {
    log('Received background message: ${message.notification?.title}');
    // Handle navigation or other actions based on the message data
    _navigateToScreen(message);
  }
}

/// Handle background messages when the app is not running.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    // Best-effort init for background isolate; avoid crashing background handler.
  }

  log(
    "Handling a background message from terminated app: ${message.notification?.body}",
  );

  // Do not attempt navigation/UI work from background isolate on iOS.
  // Navigation is handled when the user taps the notification via
  // `onMessageOpenedApp` / `getInitialMessage`.
}
