import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/network_exception.dart';

/// The only HTTP entry point for datasources.
///
/// Returns the decoded body and converts Dio errors into [ApiException] or
/// [NetworkException]; datasources never catch `DioException` themselves.
final class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Object?> get(
    String path, {
    Map<String, Object?>? query,
    Options? options,
  }) => _send(
    () => _dio.get<Object?>(path, queryParameters: query, options: options),
  );

  Future<Object?> post(
    String path, {
    Object? data,
    Map<String, Object?>? query,
    Options? options,
    ProgressCallback? onSendProgress,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: data,
      queryParameters: query,
      options: options,
      onSendProgress: onSendProgress,
    ),
  );

  Future<Object?> put(String path, {Object? data, Options? options}) =>
      _send(() => _dio.put<Object?>(path, data: data, options: options));

  Future<Object?> patch(String path, {Object? data, Options? options}) =>
      _send(() => _dio.patch<Object?>(path, data: data, options: options));

  Future<Object?> delete(String path, {Object? data, Options? options}) =>
      _send(() => _dio.delete<Object?>(path, data: data, options: options));

  Future<Object?> _send(Future<Response<Object?>> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(convertDioException(error), stackTrace);
    }
  }

  /// Bad responses → [ApiException]; no response → [NetworkException];
  /// cancellations and unknown errors are returned unchanged.
  static Exception convertDioException(DioException error) {
    final response = error.response;
    if (error.type == DioExceptionType.badResponse && response != null) {
      return ApiException.fromResponse(
        statusCode: response.statusCode ?? 0,
        body: response.data,
        retryAfterHeader: response.headers.value('retry-after'),
      );
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => NetworkException(error.type.name),
      _ => error,
    };
  }
}
