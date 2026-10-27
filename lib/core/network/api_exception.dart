import 'package:englizia/core/network/json_reader.dart';

/// A non-2xx response. Reads the server's envelope
/// (`{statusCode, message, data, error: {code, details}, traceId}`,
/// docs/api/openapi.json), else ASP.NET Core `ProblemDetails` (RFC 9457).
final class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    this.title,
    this.detail,
    this.code,
    this.fieldErrors = const {},
    this.fieldCodes = const {},
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
      final details = _parseDetails(envelopeError.readList('details'));
      return ApiException(
        statusCode: statusCode,
        detail: json.readString('message'),
        code: envelopeError.readString('code'),
        fieldErrors: details.messages,
        fieldCodes: details.codes,
        retryAfter: _parseRetryAfter(retryAfterHeader),
        traceId: json.readString('traceId'),
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

  /// The server's own message, for logs only: the app shows its own text.
  final String? detail;
  final String? code;

  /// Field name (camelCase) → the server's messages.
  final Map<String, List<String>> fieldErrors;

  /// Field name (camelCase) → stable codes (`not_empty`, …), for the app's
  /// own field messages.
  final Map<String, List<String>> fieldCodes;
  final Duration? retryAfter;

  /// Server correlation id, for support and logs.
  final String? traceId;

  /// `$.Email`, `request.Email` and `Email` all become `email`.
  static String normalizeField(String key) {
    final last = key.split('.').last.replaceAll(r'$', '');
    if (last.isEmpty) return key;
    return last[0].toLowerCase() + last.substring(1);
  }

  /// `error.details`: `[{field, code, message}]`; a detail without a field
  /// is about the whole request and stays out of the field maps.
  static ({Map<String, List<String>> messages, Map<String, List<String>> codes})
  _parseDetails(List<Object?>? raw) {
    final messages = <String, List<String>>{};
    final codes = <String, List<String>>{};
    for (final item in raw ?? const <Object?>[]) {
      if (item is! Map) continue;
      final detail = item.cast<String, Object?>();
      final field = detail.readString('field');
      if (field == null) continue;
      final key = normalizeField(field);
      if (detail.readString('message') case final message?) {
        messages[key] = [...?messages[key], message];
      }
      if (detail.readString('code') case final code?) {
        codes[key] = [...?codes[key], code];
      }
    }
    return (messages: messages, codes: codes);
  }

  /// ProblemDetails `errors`: `{Field: [messages]}`.
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
