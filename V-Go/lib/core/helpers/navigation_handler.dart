import 'package:flutter/material.dart';

import '../routing/routes.dart';
import 'extensions.dart';

class NavigationHandler {
  NavigationHandler._privateConstructor();

  static final NavigationHandler _instance =
      NavigationHandler._privateConstructor();

  static NavigationHandler get instance => _instance;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  BuildContext? get context => navigatorKey.currentContext;

  void goToLoginView() {
    context?.pushNamedAndRemoveUntil(
      Routes.accountTypeViewRoute,
      predicate: (route) => false,
    );
  }
}
