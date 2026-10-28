import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/cache/cache_helper.dart';
import 'firebase_options.dart';
import 'core/di/di.dart';
import 'core/services/firebase_notification_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/utils/app_constants.dart';
import 'my_app.dart';

bool _firebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupGetIt();

  await Future.wait(<Future<void>>[
    CacheHelper.init(),
    ScreenUtil.ensureScreenSize(),
    _portraitOnly(),
    _initFirebase(),
  ]);

  await _loadSession();

  runApp(const MyApp());
  unawaited(_initPush());
}

Future<void> _initFirebase() async {
  // Firebase initialization. Best-effort: a missing google-services.json
  // or an init failure must never block the app from starting.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: CaptainFirebaseOptions.currentPlatform);
    }
    _firebaseInitialized = true;
    _initCrashReporting();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
}

Future<void> _initPush() async {
  if (!_firebaseInitialized) return;
  try {
    await LocalNotificationService().initialize();
    await FirebaseNotificationService().initialize();
  } catch (e) {
    debugPrint('Push notifications init failed: $e');
  }
}

/// Send uncaught Flutter and async errors to Crashlytics (release builds only).
void _initCrashReporting() {
  try {
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Crash reporting init failed: $e');
  }
}

/// Hydrate the in-memory session from secure storage so the router can decide
/// whether to open the home screen or the login screen.
Future<void> _loadSession() async {
  final session = await Future.wait([
    CacheHelper.getSecuredString(AppConstants.userId),
    CacheHelper.getSecuredString(AppConstants.token),
  ]);
  AppConstants.kUserId = session[0];
  AppConstants.kToken = session[1];
  AppConstants.kRole = CacheHelper.getString(AppConstants.role);
  AppConstants.kUserName = CacheHelper.getString(AppConstants.userName);
  AppConstants.kProfileImage = CacheHelper.getString(AppConstants.profileImage);
}

Future<void> _portraitOnly() {
  return SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}
