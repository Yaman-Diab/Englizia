import 'package:englizia/core/l10n/localized_text.dart';

/// Defensive reads over decoded JSON. Models use these instead of casting, so
/// a missing or oddly typed field degrades to `null` instead of throwing.
extension JsonReader on Map<String, Object?> {
  int? readInt(String key) => switch (this[key]) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? double.tryParse(v)?.toInt(),
    _ => null,
  };

  double? readDouble(String key) => switch (this[key]) {
    final num v => v.toDouble(),
    final String v => double.tryParse(v),
    _ => null,
  };

  bool? readBool(String key) => switch (this[key]) {
    final bool v => v,
    final num v => v != 0,
    final String v => v.toLowerCase() == 'true' || v == '1',
    _ => null,
  };

  String? readString(String key) => switch (this[key]) {
    final String v when v.trim().isNotEmpty => v,
    _ => null,
  };

  Map<String, Object?>? readMap(String key) => switch (this[key]) {
    final Map<String, Object?> v => v,
    final Map<Object?, Object?> v => v.cast<String, Object?>(),
    _ => null,
  };

  /// Bilingual text `{ "ar": "…", "en": "…" }`; null when the field is
  /// absent, a missing language reads as empty.
  LocalizedText? readText(String key) => switch (readMap(key)) {
    final Map<String, Object?> text => LocalizedText(
      ar: text.readString('ar') ?? '',
      en: text.readString('en') ?? '',
    ),
    null => null,
  };

  List<Object?>? readList(String key) => switch (this[key]) {
    final List<Object?> v => v,
    _ => null,
  };

  /// ISO-8601 timestamp as sent by the server (usually UTC).
  /// Convert to local time only when formatting for display.
  DateTime? readDateTime(String key) => switch (this[key]) {
    final String v => DateTime.tryParse(v),
    _ => null,
  };

  /// First non-null value among candidate keys (for unconfirmed contracts).
  T? firstOf<T>(List<String> keys, T? Function(String key) read) {
    for (final key in keys) {
      final value = read(key);
      if (value != null) return value;
    }
    return null;
  }
}

/// Casts a decoded response body to a JSON object or throws [FormatException].
Map<String, Object?> asJsonMap(Object? data) => switch (data) {
  final Map<String, Object?> v => v,
  final Map<Object?, Object?> v => v.cast<String, Object?>(),
  _ => throw FormatException('Expected a JSON object, got ${data.runtimeType}'),
};
