import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../api/dio_factory.dart';
import '../di/di.dart';
import '../services/realtime_service.dart';
import 'navigation_handler.dart';

/// The admin blocked this account. The server answers every request with
/// 403 `ACCOUNT_BLOCKED` (and pushes `AccountBlocked` on the hubs), and the
/// app goes offline and signs out right away.
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
      try {
        await getIt<RealtimeService>().disconnect();
      } catch (_) {}
      await TokenService().clearTokens();
      NavigationHandler.instance.goToLoginView();
      final context = NavigationHandler.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('الحساب موقوف'),
            content: Text(message ?? defaultMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } finally {
      _handling = false;
    }
  }
}
