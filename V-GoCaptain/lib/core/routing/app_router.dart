import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/data/repo/auth_repo.dart';
import '../../features/auth/presentation/logic/cubit/auth_cubit.dart';
import '../../features/auth/presentation/views/change_password_view.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/new_password_view.dart';
import '../../features/auth/presentation/views/otp_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/reset_password_view.dart';
import '../../features/shell/presentation/views/captain_shell_view.dart';
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

  /// Wraps an auth screen with a fresh AuthCubit.
  static Widget _auth(Widget child) => BlocProvider(
        create: (_) => AuthCubit(getIt<AuthRepo>()),
        child: child,
      );

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;

    switch (settings.name) {
      case Routes.loginViewRoute:
        return _page(_auth(const LoginView()));

      case Routes.registerViewRoute:
        return _page(_auth(const RegisterView()));

      case Routes.otpViewRoute:
        return _page(_auth(OtpView(
          email: args?['email'] as String? ?? '',
          type: args?['type'] as String? ?? 'Register',
        )));

      case Routes.resetPasswordViewRoute:
        return _page(_auth(const ResetPasswordView()));

      case Routes.newPasswordViewRoute:
        return _page(_auth(NewPasswordView(
          email: args?['email'] as String? ?? '',
        )));

      case Routes.changePasswordViewRoute:
        return _page(_auth(const ChangePasswordView()));

      case Routes.captainHomeViewRoute:
        return _page(const CaptainShellView());

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
