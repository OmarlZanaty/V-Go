import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/data/repo/auth_repo.dart';
import '../../features/auth/presentation/logic/cubit/auth_cubit.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/home/presentation/views/captain_home_view.dart';
import '../di/di.dart';
import '../utils/app_constants.dart';
import 'routes.dart';

class AppRouter {
  AppRouter._();

  /// Decide the first screen: home if a token is already cached, else login.
  static String initialRoute() {
    return AppConstants.kToken.isNotEmpty
        ? Routes.captainHomeViewRoute
        : Routes.loginViewRoute;
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.loginViewRoute:
        return _page(
          BlocProvider(
            create: (_) => AuthCubit(getIt<AuthRepo>()),
            child: const LoginView(),
          ),
        );

      case Routes.captainHomeViewRoute:
        return _page(const CaptainHomeView());

      default:
        return _page(
          const Scaffold(
            body: Center(child: Text('No route defined')),
          ),
        );
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget child) =>
      MaterialPageRoute(builder: (_) => child);
}
