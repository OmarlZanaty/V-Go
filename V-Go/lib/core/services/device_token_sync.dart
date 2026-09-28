import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';

import '../api/api_service.dart';
import '../api/end_points.dart';
import '../cache/cache_helper.dart';
import '../helpers/app_type.dart';
import '../utils/app_constants.dart';

/// Keeps the backend's copy of this phone's FCM token current.
///
/// The token used to be sent exactly once, inside the login request. Anyone
/// already signed in when the app was reinstalled, restored from backup, or
/// whose token Firebase simply rotated, kept a dead token on the server and
/// received nothing until they signed out and back in. Now it is re-sent on
/// every launch while signed in, right after a login, and on `onTokenRefresh`.
///
/// Best-effort: a failed sync is logged, never surfaced.
class DeviceTokenSync {
  DeviceTokenSync._();

  static bool _listening = false;

  /// Call once after DI is ready. Safe to call more than once.
  static void start() {
    if (_listening) return;
    _listening = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      CacheHelper.setData(key: AppConstants.fcmToken, value: token);
      sync(token: token);
    });
    sync();
  }

  /// Send the current token if the user is signed in.
  static Future<void> sync({String? token}) async {
    try {
      final jwt = await CacheHelper.getSecuredString(AppConstants.token);
      if (jwt.isEmpty) return; // nobody to register it for
      final fcm = token ?? CacheHelper.getString(AppConstants.fcmToken);
      if (fcm.isEmpty) return;
      await GetIt.I<ApiServices>().post(
        EndPoint.registerDevice,
        data: {'fcmToken': fcm, 'deviceType': deviceType()},
      );
      log('DeviceTokenSync: registered ${fcm.substring(0, 12)}…');
    } catch (e) {
      log('DeviceTokenSync failed: $e');
    }
  }
}
