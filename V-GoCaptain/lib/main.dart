import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/cache/cache_helper.dart';
import 'core/di/di.dart';
import 'core/utils/app_constants.dart';
import 'my_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupGetIt();

  await Future.wait(<Future<void>>[
    CacheHelper.init(),
    ScreenUtil.ensureScreenSize(),
    _portraitOnly(),
  ]);

  await _loadSession();

  runApp(const MyApp());
}

/// Hydrate the in-memory session from secure storage so the router can decide
/// whether to open the home screen or the login screen.
Future<void> _loadSession() async {
  AppConstants.kUserId = await CacheHelper.getSecuredString(AppConstants.userId);
  AppConstants.kToken = await CacheHelper.getSecuredString(AppConstants.token);
  AppConstants.kRole = CacheHelper.getString(AppConstants.role);
}

Future<void> _portraitOnly() {
  return SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}
