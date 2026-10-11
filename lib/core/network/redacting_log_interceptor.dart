import 'package:dio/dio.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/logging/redactor.dart';

/// Debug-only HTTP log. Headers are never logged; bodies and query values
/// are redacted and truncated. `DioFactory` adds it only in debug builds.
class RedactingLogInterceptor extends Interceptor {
  static const _startedAtKey = 'log.started_at';
  static const _maxBodyLength = 1500;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now();
    AppLogger.debug(
      '→ ${options.method} ${_uri(options.uri)}${_body(options.data)}',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    AppLogger.debug(
      '← ${response.statusCode} ${options.method} ${_uri(options.uri)} '
      '(${_elapsed(options)})${_body(response.data)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    AppLogger.debug(
      '✕ ${err.response?.statusCode ?? err.type.name} ${options.method} '
      '${_uri(options.uri)} (${_elapsed(options)})'
      '${_body(err.response?.data)}',
    );
    handler.next(err);
  }

  String _elapsed(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey];
    if (startedAt is! DateTime) return '?';
    return '${DateTime.now().difference(startedAt).inMilliseconds}ms';
  }

  String _uri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri.toString();
    return uri
        .replace(
          queryParameters: {
            for (final entry in uri.queryParameters.entries)
              entry.key: Redactor.isSensitiveKey(entry.key)
                  ? Redactor.mask
                  : entry.value,
          },
        )
        .toString();
  }

  String _body(Object? data) {
    if (data == null) return '';
    final text = data is FormData
        ? '[multipart]'
        : '${Redactor.redactJson(data)}';
    final clipped = text.length > _maxBodyLength
        ? '${text.substring(0, _maxBodyLength)}…'
        : text;
    return '\n$clipped';
  }
}
