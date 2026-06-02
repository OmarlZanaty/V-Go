import 'package:dio/dio.dart';

import 'api_requests.dart';

class ApiServices implements ApiRequests {
  ApiServices({required Dio dio}) : _dio = dio;
  final Dio _dio;

  //! Get Request
  @override
  Future<dynamic> get(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isFormData = false,
  }) async {
    final response = await _dio.get(
      path,
      data: isFormData ? FormData.fromMap(data) : data,
      queryParameters: queryParameters,
    );
    return response.data;
  }

  //! Post Request
  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    void Function(int, int)? onSendProgress,
    bool isFormData = false,
  }) async {
    final response = await _dio.post(
      path,
      options: Options(headers: headers),
      data: isFormData ? FormData.fromMap(data) : data,
      queryParameters: queryParameters,
      onSendProgress: onSendProgress,
    );
    return response.data;
  }

  //! Delete Request
  @override
  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isFormData = false,
  }) async {
    final response = await _dio.delete(
      path,
      data: isFormData ? FormData.fromMap(data) : data,
      queryParameters: queryParameters,
    );
    return response.data;
  }

  //! Patch Request
  @override
  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isFormData = false,
  }) async {
    final response = await _dio.patch(
      path,
      data: isFormData ? FormData.fromMap(data) : data,
      queryParameters: queryParameters,
    );
    return response.data;
  }

  //! Put Request
  @override
  Future put(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    bool isFormData = false,
  }) async {
    final response = await _dio.put(
      path,
      data: isFormData ? FormData.fromMap(data) : data,
      queryParameters: queryParameters,
    );
    return response.data;
  }
}
