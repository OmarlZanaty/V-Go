import 'package:dio/dio.dart';

import 'failure.dart';

/// Central failure → Arabic message mapper. Every user-facing error must pass
/// through here so users never see raw English / technical text.
class ServerFailure extends Failure {
  ServerFailure(String errMessage) : super(errMessage: errMessage);

  factory ServerFailure.fromError(dynamic e) {
    if (e is DioException) return ServerFailure._fromDioError(e);
    // SignalR / app code throw ready Arabic message strings — keep them.
    if (e is String && e.trim().isNotEmpty) return ServerFailure(e);
    if (e is Failure) return ServerFailure(e.errMessage);
    return ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى.');
  }

  factory ServerFailure._fromDioError(DioException dioError) {
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
        return ServerFailure(
          'انتهت مهلة الاتصال بالخادم، تحقق من الإنترنت وحاول مجددًا.',
        );
      case DioExceptionType.sendTimeout:
        return ServerFailure(
          'تأخر إرسال البيانات، تحقق من الإنترنت وحاول مجددًا.',
        );
      case DioExceptionType.receiveTimeout:
        return ServerFailure('تأخر استقبال البيانات من الخادم، حاول مجددًا.');
      case DioExceptionType.badResponse:
        return ServerFailure._fromResponse(
          dioError.response?.statusCode ?? 0,
          dioError.response?.data,
        );
      case DioExceptionType.cancel:
        return ServerFailure('تم إلغاء الطلب.');
      case DioExceptionType.connectionError:
        return ServerFailure(
          'لا يوجد اتصال بالإنترنت، تحقق من الشبكة وحاول مجددًا.',
        );
      case DioExceptionType.badCertificate:
        return ServerFailure('تعذّر التحقق من أمان الاتصال، حاول مجددًا.');
      case DioExceptionType.unknown:
        final msg = dioError.message ?? '';
        if (msg.contains('SocketException') || msg.contains('Failed host')) {
          return ServerFailure(
            'لا يوجد اتصال بالإنترنت، تحقق من الشبكة وحاول مجددًا.',
          );
        }
        return ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى.');
    }
  }

  factory ServerFailure._fromResponse(int statusCode, dynamic response) {
    // Prefer the backend's own (Arabic) message when it sends one.
    final backendMsg = _extractMessage(response);
    switch (statusCode) {
      case 400:
        return ServerFailure(backendMsg ?? 'بيانات الطلب غير صحيحة، يرجى مراجعتها.');
      case 401:
        return ServerFailure(
          backendMsg ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجددًا.',
        );
      case 403:
        return ServerFailure(backendMsg ?? 'ليس لديك صلاحية لتنفيذ هذا الإجراء.');
      case 404:
        return ServerFailure(backendMsg ?? 'العنصر المطلوب غير موجود.');
      case 408:
        return ServerFailure('انتهت مهلة الطلب، حاول مجددًا.');
      case 409:
        return ServerFailure(backendMsg ?? 'تعارض في البيانات، يرجى المحاولة مجددًا.');
      case 422:
        return ServerFailure(backendMsg ?? 'تعذّر معالجة البيانات المُدخلة.');
      case 429:
        return ServerFailure('عدد محاولات كثيرة، يرجى الانتظار قليلًا ثم المحاولة.');
      case 500:
        return ServerFailure('خطأ في الخادم، يرجى المحاولة لاحقًا.');
      case 502:
      case 503:
      case 504:
        return ServerFailure('الخدمة غير متاحة مؤقتًا، يرجى المحاولة بعد قليل.');
      default:
        return ServerFailure(
          backendMsg ?? 'عذرًا، حدث خطأ ما، يرجى المحاولة مرة أخرى.',
        );
    }
  }

  /// Pull a human message out of common backend shapes (string, {message},
  /// {errors:{field:[..]}}, etc.).
  static String? _extractMessage(dynamic response) {
    if (response == null) return null;
    if (response is String) {
      return response.trim().isEmpty ? null : response;
    }
    if (response is Map) {
      final m = response['message'] ??
          response['Message'] ??
          response['error'] ??
          response['title'];
      if (m != null && m.toString().trim().isNotEmpty) return m.toString();
      final errs = response['errors'] ?? response['Errors'];
      if (errs is Map && errs.isNotEmpty) {
        final first = errs.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
      if (errs is List && errs.isNotEmpty) return errs.first.toString();
    }
    return null;
  }
}
