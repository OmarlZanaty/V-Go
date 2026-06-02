import 'package:dio/dio.dart';

import 'failure.dart';

class ServerFailure extends Failure {
  ServerFailure(String errMessage) : super(errMessage: errMessage);

  factory ServerFailure.fromError(dynamic e) {
    if (e is DioException) {
      return ServerFailure._fromDioError(e);
    } else {
      return ServerFailure(e.toString());
    }
  }

  factory ServerFailure._fromDioError(DioException dioError) {
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
        return ServerFailure('انتهت مهلة الاتصال بالخادم');
      case DioExceptionType.sendTimeout:
        return ServerFailure('انتهت مهلة إرسال البيانات إلى الخادم');
      case DioExceptionType.receiveTimeout:
        return ServerFailure('انتهت مهلة استقبال البيانات من الخادم');
      case DioExceptionType.badResponse:
        return ServerFailure._fromResponse(
          dioError.response!.statusCode!,
          dioError.response!.data,
        );
      case DioExceptionType.cancel:
        return ServerFailure('تم إلغاء الطلب إلى الخادم');
      case DioExceptionType.connectionError:
        return ServerFailure('لا يوجد اتصال بالإنترنت');
      case DioExceptionType.unknown:
        return ServerFailure('حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى');
      case DioExceptionType.badCertificate:
        return ServerFailure('خطأ في الشهادة');
    }
  }

  factory ServerFailure._fromResponse(int statusCode, dynamic response) {
    if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
      return ServerFailure(
        (response != null && (response is String || response is Map)
            ? (response is String
                      ? response
                      : response['message']?.toString()) ??
                  'طلب غير صالح، يرجى المحاولة مرة أخرى'
            : 'طلب غير صالح، يرجى المحاولة مرة أخرى'),
      );
    } else if (statusCode == 404) {
      return ServerFailure(
        (response != null && (response is String || response is Map)
            ? (response is String
                      ? response
                      : response['message']?.toString()) ??
                  'غير موجود، يرجى المحاولة مرة أخرى'
            : 'غير موجود، يرجى المحاولة مرة أخرى'),
      );
    } else if (statusCode == 500) {
      return ServerFailure('خطأ في الخادم الداخلي، يرجى المحاولة لاحقًا!');
    } else {
      return ServerFailure('عذراً، حدث خطأ ما، يرجى المحاولة مرة أخرى');
    }
  }
}
