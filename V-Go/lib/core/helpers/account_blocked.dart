import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';

import '../api/dio_factory.dart';
import '../api/end_points.dart';
import '../theming/app_colors.dart';
import '../theming/app_style.dart';
import '../utils/app_constants.dart';
import 'navigation_handler.dart';

/// The admin blocked this account. The server answers every request with
/// 403 `ACCOUNT_BLOCKED` (and pushes `AccountBlocked` on the trip hub), and the
/// app signs out right away instead of waiting for the next login.
class AccountBlocked {
  AccountBlocked._();

  static const code = 'ACCOUNT_BLOCKED';
  static const defaultMessage = 'حسابك موقوف، تواصل مع الدعم';
  static bool _handling = false;

  static bool isBlockedResponse(Response? response) {
    final data = response?.data;
    return response?.statusCode == 403 && data is Map && data['code'] == code;
  }

  static Future<void> signOut([String? message]) async {
    if (_handling) return;
    _handling = true;
    try {
      await TokenService().clearTokens();
      AppConstants.kToken = '';
      NavigationHandler.instance.goToLoginView();
      final context = NavigationHandler.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'الحساب موقوف',
          desc: message ?? defaultMessage,
          dialogBackgroundColor: AppColors.darkGrey,
          titleTextStyle: AppStyle.styleMedium16.copyWith(
            color: AppColors.white,
          ),
          descTextStyle: AppStyle.styleRegular14.copyWith(
            color: AppColors.white,
          ),
          btnOkText: 'حسناً',
          btnOkOnPress: () {},
        ).show();
      }
    } finally {
      _handling = false;
    }
  }

  /// Called when the app returns to the foreground: any authed request will do,
  /// the interceptor signs out if the account was blocked meanwhile.
  static Future<void> check() async {
    if (AppConstants.kUserId.isEmpty) return;
    try {
      await DioFactory.getDio().get(EndPoint.getUserById(AppConstants.kUserId));
    } catch (_) {}
  }
}
