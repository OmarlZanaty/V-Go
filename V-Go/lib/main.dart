import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/cache/cache_helper.dart';
import 'core/di/di.dart';
import 'core/services/firebase_notification_service.dart';
import 'core/services/flutter_local_notification_service.dart';
import 'core/services/hive_service.dart';
import 'core/utils/app_constants.dart';
import 'firebase_options.dart';
import 'my_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  setupGetIt();
  //Bloc.observer = MyBlocObserver();
  await Future.wait(<Future<void>>[
    CacheHelper.init(),
    ScreenUtil.ensureScreenSize(),
    _systemChromeConfig(),
  ]);

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await Future.wait(<Future<void>>[
      _initUserData(),
      FirebaseNotificationService().initialize(),
      LocalNotificationService().initialize(),
      HiveService.initHive(),
    ]);
  } catch (e) {
    debugPrint('App initialization step failed: $e');
  }

  runApp(const MyApp());
}

Future<void> _initUserData() async {
  AppConstants.kUserId = await CacheHelper.getSecuredString(
    AppConstants.userId,
  );
  AppConstants.kToken = await CacheHelper.getSecuredString(AppConstants.token);
  AppConstants.kRole = CacheHelper.getString(AppConstants.role);
}

// to make sure that the device orientation is set to portrait
Future<void> _systemChromeConfig() {
  return SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}
