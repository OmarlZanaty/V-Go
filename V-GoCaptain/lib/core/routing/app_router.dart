import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/data/repo/auth_repo.dart';
import '../../features/auth/presentation/logic/cubit/auth_cubit.dart';
import '../../features/auth/presentation/logic/phone_auth_cubit/phone_auth_cubit.dart';
import '../../features/auth/presentation/views/change_password_view.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/phone_driver_signup_view.dart';
import '../../features/auth/presentation/views/phone_login_view.dart';
import '../../features/auth/presentation/views/new_password_view.dart';
import '../../features/auth/presentation/views/otp_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/reset_password_view.dart';
import '../../features/profile/data/repo/profile_repo.dart';
import '../../features/profile/presentation/cubit/ratings_cubit.dart';
import '../../features/profile/presentation/cubit/scooter_cubit.dart';
import '../../features/profile/presentation/cubit/support_cubit.dart';
import '../../features/profile/presentation/views/pdf_viewer_view.dart';
import '../../features/profile/presentation/views/ratings_view.dart';
import '../../features/profile/presentation/views/scooter_view.dart';
import '../../features/profile/presentation/views/settings_view.dart';
import '../../features/profile/presentation/views/support_view.dart';
import '../../features/profile/presentation/views/terms_view.dart';
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
        : Routes.phoneLoginViewRoute;
  }

  /// Wraps an auth screen with a fresh AuthCubit.
  static Widget _auth(Widget child) => BlocProvider(
        create: (_) => AuthCubit(getIt<AuthRepo>()),
        child: child,
      );

  /// Wraps a phone-auth screen with a fresh PhoneAuthCubit.
  static Widget _phoneAuth(Widget child) => BlocProvider(
        create: (_) => PhoneAuthCubit(getIt<AuthRepo>()),
        child: child,
      );

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;

    switch (settings.name) {
      case Routes.loginViewRoute:
        return _page(_auth(const LoginView()));

      case Routes.phoneLoginViewRoute:
        return _page(_phoneAuth(const PhoneLoginView()));

      case Routes.phoneDriverSignupViewRoute:
        return _page(_phoneAuth(
          PhoneDriverSignupView(phone: args?['phone'] as String? ?? ''),
        ));

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

      case Routes.scooterViewRoute:
        return _page(BlocProvider(
          create: (_) => ScooterCubit(getIt<ProfileRepo>())..load(),
          child: const ScooterView(),
        ));

      case Routes.ratingsViewRoute:
        return _page(BlocProvider(
          create: (_) => RatingsCubit(getIt<ProfileRepo>())..load(),
          child: const RatingsView(),
        ));

      case Routes.supportViewRoute:
        return _page(BlocProvider(
          create: (_) => SupportCubit(getIt<ProfileRepo>()),
          child: const SupportView(),
        ));

      case Routes.settingsViewRoute:
        return _page(const SettingsView());

      case Routes.termsViewRoute:
        return _page(const TermsView());

      case Routes.pdfViewRoute:
        return _page(PdfViewerView(
          assetPath:
              args?['assetPath'] as String? ?? 'assets/files/policy.pdf',
          title: args?['title'] as String? ?? 'سياسة الخصوصية',
        ));

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
