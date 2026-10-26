import 'package:englizia/core/network/json_reader.dart';

/// A non-2xx response. Reads the `error` object of the unified envelope
/// (`{code, message, fieldErrors, traceId}`), else ASP.NET Core
/// `ProblemDetails` (RFC 9457).
// ASSUMPTION(api): neither shape is confirmed; validation errors come as
// `{Field: [messages]}` in both, business errors carry a stable `code` —
// confirm in docs/api/README.md.
final class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    this.title,
    this.detail,
    this.code,
    this.fieldErrors = const {},
    this.retryAfter,
    this.traceId,
  });

  factory ApiException.fromResponse({
    required int statusCode,
    Object? body,
    String? retryAfterHeader,
  }) {
    final json = switch (body) {
      final Map<Object?, Object?> map => map.cast<String, Object?>(),
      _ => const <String, Object?>{},
    };
    final envelopeError = json.readMap('error');
    if (envelopeError != null) {
      return ApiException(
        statusCode: statusCode,
        detail: envelopeError.readString('message'),
        code: envelopeError.readString('code'),
        fieldErrors: _parseFieldErrors(envelopeError['fieldErrors']),
        retryAfter: _parseRetryAfter(retryAfterHeader),
        traceId: envelopeError.readString('traceId'),
      );
    }
    return ApiException(
      statusCode: statusCode,
      title: json.readString('title'),
      detail: json.firstOf(['detail', 'message'], json.readString),
      code: json.firstOf(['code', 'errorCode'], json.readString),
      fieldErrors: _parseFieldErrors(json['errors']),
      retryAfter: _parseRetryAfter(retryAfterHeader),
      traceId: json.readString('traceId'),
    );
  }

  final int statusCode;
  final String? title;
  final String? detail;
  final String? code;
  final Map<String, List<String>> fieldErrors;
  final Duration? retryAfter;

  /// Server correlation id, for support and logs.
  final String? traceId;

  /// `$.Email`, `request.Email` and `Email` all become `email`.
  static String normalizeField(String key) {
    final last = key.split('.').last.replaceAll(r'$', '');
    if (last.isEmpty) return key;
    return last[0].toLowerCase() + last.substring(1);
  }

  static Map<String, List<String>> _parseFieldErrors(Object? raw) {
    if (raw is! Map<Object?, Object?>) return const {};
    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      final messages = switch (entry.value) {
        final List<Object?> list => list.whereType<String>().toList(),
        final String message => [message],
        _ => const <String>[],
      };
      if (messages.isEmpty) continue;
      final field = normalizeField('${entry.key}');
      result[field] = [...?result[field], ...messages];
    }
    return result;
  }

  static Duration? _parseRetryAfter(String? header) {
    final seconds = int.tryParse(header ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  @override
  String toString() => 'ApiException($statusCode, code: $code, title: $title)';
}
