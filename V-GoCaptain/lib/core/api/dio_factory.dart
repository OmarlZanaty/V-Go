import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../cache/cache_helper.dart';
import '../helpers/account_blocked.dart';
import '../helpers/navigation_handler.dart';
import '../utils/app_constants.dart';
import 'end_points.dart';
import 'retry_interceptor.dart';

class DioFactory {
  DioFactory._();

  static Dio? dio;
  static final _tokenService = TokenService();

  static Dio getDio() {
    if (dio == null) {
      dio = Dio();
      dio!
        ..options.baseUrl = EndPoint.baseUrl
        ..options.connectTimeout = const Duration(seconds: 30)
        ..options.receiveTimeout = const Duration(minutes: 5);
      _addHeaders();
      _addInterceptors();
    }
    return dio!;
  }

  static Future<void> _addHeaders() async {
    final userToken = await CacheHelper.getSecuredString(AppConstants.token);
    dio?.options.headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $userToken',
    };
  }

  static Future<void> setTokenIntoHeaderAfterLogin(String token) async {
    TokenService._signedOut = false;
    dio?.options.headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static void _addInterceptors() {
    dio?.interceptors.addAll(<Interceptor>[
      if (kDebugMode)
        PrettyDioLogger(
          requestBody: true,
          requestHeader: true,
          responseHeader: true,
        ),
      RetryInterceptor(dio!),
      _authInterceptor(),
    ]);
  }

  static Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await _tokenService.getAccessToken();
        if (accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (AccountBlocked.isBlockedResponse(error.response)) {
          final data = error.response!.data as Map;
          await AccountBlocked.signOut(data['message']?.toString());
          return handler.next(error);
        }
        if (error.requestOptions.path.contains(EndPoint.newRefreshToken)) {
          return handler.next(error);
        }
        final alreadyRetried = error.requestOptions.extra['retried'] == true;
        if (error.response?.statusCode == 401 &&
            !alreadyRetried &&
            (await _tokenService.getRefreshToken()).isNotEmpty) {
          try {
            await _tokenService.refreshToken();
            final accessToken = await _tokenService.getAccessToken();
            error.requestOptions.headers['Authorization'] =
                'Bearer $accessToken';
            error.requestOptions.extra['retried'] = true;
            final cloned = await dio!.fetch(error.requestOptions);
            return handler.resolve(cloned);
          } catch (_) {
            return handler.next(error);
          }
        }
        return handler.next(error);
      },
    );
  }
}

class TokenService {
  static bool _signedOut = false;
  static final _refreshDio = Dio(BaseOptions(
    baseUrl: EndPoint.baseUrl,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<String> getAccessToken() =>
      CacheHelper.getSecuredString(AppConstants.token);

  // Shared so concurrent callers (HTTP and SignalR) trigger a single refresh —
  // the backend rotates refresh tokens, so a second parallel refresh would fail.
  static Future<void>? _refreshing;

  /// Access token that is guaranteed not to be (about to be) expired. Used by
  /// SignalR, which has no Dio interceptor to refresh on 401.
  Future<String> getFreshAccessToken() async {
    final token = await getAccessToken();
    if (token.isEmpty || !_isExpiring(token)) return token;
    if ((await getRefreshToken()).isEmpty) return token;
    try {
      await refreshToken();
      return await getAccessToken();
    } catch (_) {
      return token;
    }
  }

  static bool _isExpiring(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'];
      if (exp is! num) return false;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return DateTime.now()
          .toUtc()
          .isAfter(expiry.subtract(const Duration(minutes: 2)));
    } catch (_) {
      return false;
    }
  }

  Future<String> getRefreshToken() =>
      CacheHelper.getSecuredString(AppConstants.refreshToken);

  Future<void> setTokens(String accessToken, String refreshToken) async {
    await CacheHelper.setSecuredString(AppConstants.token, accessToken);
    await CacheHelper.setSecuredString(AppConstants.refreshToken, refreshToken);
    // Keep the in-memory token in sync (SignalR reads it for reconnects).
    AppConstants.kToken = accessToken;
    _signedOut = false;
  }

  Future<void> clearTokens() async {
    await CacheHelper.clearAllSecuredData();
    await CacheHelper.removeData(key: AppConstants.role);
    AppConstants.kUserId = '';
    AppConstants.kRole = '';
    AppConstants.kToken = '';
  }

  Future<void> signOutOnce() async {
    if (_signedOut) return;
    _signedOut = true;
    try {
      await clearTokens();
    } finally {
      NavigationHandler.instance.goToLoginView();
    }
  }

  Future<void> refreshToken() {
    return _refreshing ??=
        _refreshToken().whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshToken() async {
    try {
      final refresh = await getRefreshToken();
      if (_signedOut || refresh.isEmpty) return;
      final response = await _refreshDio.post(
        EndPoint.newRefreshToken,
        queryParameters: {'token': refresh},
      );
      await setTokens(response.data['token'], response.data['refreshToken']);
      await DioFactory.setTokenIntoHeaderAfterLogin(response.data['token']);
    } catch (e) {
      if (e is DioException &&
          (e.response?.statusCode == 400 ||
              e.response?.statusCode == 401 ||
              e.response?.statusCode == 403)) {
        await signOutOnce();
      }
      rethrow;
    }
  }
}
