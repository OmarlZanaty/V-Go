import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../cache/cache_helper.dart';
import '../errors/exception.dart';
import '../helpers/navigation_handler.dart';
import '../utils/app_constants.dart';
import 'end_points.dart';

class DioFactory {
  DioFactory._();

  static Dio? dio;
  static final _tokenService = TokenService();

  static Dio getDio() {
    if (dio == null) {
      dio = Dio();
      dio!
        ..options.baseUrl = EndPoint.baseUrl
        ..options.connectTimeout = const Duration(seconds: 90)
        ..options.receiveTimeout = const Duration(minutes: 5);
      addDioHeaders();
      addDioInterceptor();
      return dio!;
    } else {
      return dio!;
    }
  }

  static Future<void> addDioHeaders() async {
    final userToken = await CacheHelper.getSecuredString(AppConstants.token);
    dio?.options.headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $userToken',
    };
  }

  static Future<void> setTokenIntoHeaderAfterLogin(String token) async {
    dio?.options.headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static void addDioInterceptor() {
    final interceptors = <Interceptor>[
      if (kDebugMode)
        PrettyDioLogger(
          requestBody: true,
          requestHeader: true,
          responseHeader: true,
        ),
      _createAuthInterceptor(),
    ];
    dio?.interceptors.addAll(interceptors);
  }

  static int retryCount = 0;
  static Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await _tokenService.getAccessToken();
        options.headers['Authorization'] = 'Bearer $accessToken';
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401 &&
            retryCount < 1 &&
            await _tokenService.getRefreshToken() != '') {
          retryCount++;
          try {
            await _tokenService.refreshToken();
            final accessToken = await _tokenService.getAccessToken();
            error.requestOptions.headers['Authorization'] =
                'Bearer $accessToken';
            final clonedRequest = await dio!.fetch(error.requestOptions);
            return handler.resolve(clonedRequest);
          } catch (e) {
            await _tokenService.clearTokens();
            NavigationHandler.instance.goToLoginView();
            return handler.next(error);
          }
        } else {
          return handler.next(error);
        }
      },
    );
  }
}

class TokenService {
  Future<String> getAccessToken() async {
    return await CacheHelper.getSecuredString(AppConstants.token);
  }

  Future<String> getRefreshToken() async {
    return await CacheHelper.getSecuredString(AppConstants.refreshToken);
  }

  Future<void> setTokens(String accessToken, String refreshToken) async {
    await CacheHelper.setSecuredString(AppConstants.token, accessToken);
    await CacheHelper.setSecuredString(AppConstants.refreshToken, refreshToken);
  }

  Future<void> clearTokens() async {
    await Future.wait(<Future<void>>[
      CacheHelper.clearAllSecuredData(),
      CacheHelper.removeData(key: AppConstants.role),
      CacheHelper.removeData(key: AppConstants.gender),
    ]);
    AppConstants.kUserId = '';
    AppConstants.kRole = '';
  }

  Future<void> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      final response = await DioFactory.getDio().post(
        EndPoint.newRefreshToken,
        queryParameters: {'token': refreshToken},
      );
      await setTokens(response.data['token'], response.data['refreshToken']);
      DioFactory.setTokenIntoHeaderAfterLogin(response.data['token']);
    } catch (e) {
      throw ServerFailure.fromError(e);
    }
  }
}

class DioUtil {
  static Dio? _dio;

  static Dio get instance {
    _dio ??= Dio()
      ..interceptors.addAll([
        if (kDebugMode)
          PrettyDioLogger(
            requestHeader: true,
            requestBody: true,
            responseHeader: true,
          ),
      ]);
    return _dio!;
  }
}
