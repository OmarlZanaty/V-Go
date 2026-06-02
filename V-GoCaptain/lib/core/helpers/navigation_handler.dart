import 'package:flutter/material.dart';

import '../routing/routes.dart';

class NavigationHandler {
  NavigationHandler._();

  static final NavigationHandler _instance = NavigationHandler._();
  static NavigationHandler get instance => _instance;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  BuildContext? get context => navigatorKey.currentContext;

  void goToLoginView() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      Routes.loginViewRoute,
      (route) => false,
    );
  }

  void goToHome() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      Routes.captainHomeViewRoute,
      (route) => false,
    );
  }
}
