import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../cache/cache_helper.dart';
import '../helpers/navigation_handler.dart';
import '../routing/routes.dart';
import '../utils/app_constants.dart';
import 'local_notification_service.dart';

/// Handles Firebase Cloud Messaging for the captain app: permission, token
/// registration/refresh, and foreground/background/terminated message handling.
class FirebaseNotificationService {
  FirebaseNotificationService._();
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._();
  factory FirebaseNotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      await _messaging.requestPermission();

      // Show a heads-up notification for foreground messages.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      // Handle taps that bring the app from background to foreground.
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

      // Register the device token (the existing login flow sends it to the
      // backend; it's stored in secure storage where the login reads it).
      final token = await _messaging.getToken();
      if (token != null) {
        await CacheHelper.setSecuredString(AppConstants.fcmToken, token);
        log('FCM token registered');
      }
      _messaging.onTokenRefresh.listen((t) {
        CacheHelper.setSecuredString(AppConstants.fcmToken, t);
      });

      // App opened from a terminated state by tapping a notification.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _openHome();
    } catch (e) {
      log('FirebaseNotificationService init failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n != null) {
      LocalNotificationService().showNotification(
        title: n.title ?? 'رحلة جديدة',
        body: n.body ?? '',
      );
    }
  }

  void _onMessageOpened(RemoteMessage message) => _openHome();

  /// New-trip alerts are served on the home shell (the live offer card), so a
  /// tap simply brings the captain there.
  void _openHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationHandler.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        Routes.captainHomeViewRoute,
        (route) => false,
      );
    });
  }
}

/// Background/terminated message handler (top-level entry point). FCM renders
/// the notification automatically via the manifest's default channel, so we
/// only need to make sure Firebase is initialized in this isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Best-effort: never crash the background isolate.
  }
}
