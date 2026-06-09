import 'package:dio/dio.dart';

/// Auto-retries transient network failures with exponential backoff.
///
/// Safe by design: only **idempotent** requests are retried automatically
/// (GET/HEAD). A mutation (POST/PUT/PATCH/DELETE) is only retried if the caller
/// explicitly opts in via `options.extra['retryable'] = true` — use that ONLY
/// when the endpoint is idempotent (e.g. guarded by a unique key), otherwise a
/// retry could duplicate the action (double trip / double charge).
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this.dio, {this.maxRetries = 3});

  final Dio dio;
  final int maxRetries;

  static const _delays = [
    Duration(milliseconds: 400),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  bool _isTransient(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        final code = e.response?.statusCode;
        return code == 502 || code == 503 || code == 504;
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;
    final method = opts.method.toUpperCase();
    final attempt = (opts.extra['retry_attempt'] as int?) ?? 0;
    final idempotent = method == 'GET' ||
        method == 'HEAD' ||
        opts.extra['retryable'] == true;

    if (idempotent && attempt < maxRetries && _isTransient(err)) {
      await Future.delayed(_delays[attempt.clamp(0, _delays.length - 1)]);
      opts.extra['retry_attempt'] = attempt + 1;
      try {
        final response = await dio.fetch(opts);
        return handler.resolve(response);
      } on DioException catch (e) {
        return handler.next(e);
      } catch (_) {
        return handler.next(err);
      }
    }
    return handler.next(err);
  }
}
