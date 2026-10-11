/// Masks credentials and personal data before anything is logged.
abstract final class Redactor {
  static const mask = '***';

  static const _sensitiveKeyParts = [
    'authorization',
    'cookie',
    'password',
    'token',
    'secret',
    'otp',
    'phone',
    'mobile',
    'email',
    'national',
  ];

  static final _bearer = RegExp(
    r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  // Contiguous 9–15 digits; ignores GUID fragments and short numeric ids.
  static final _phone = RegExp(r'(?<![\w-])\+?\d{9,15}(?![\w-])');

  static bool isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return _sensitiveKeyParts.any(lower.contains);
  }

  static String redactText(String text) => text
      .replaceAll(_bearer, 'Bearer $mask')
      .replaceAll(_email, mask)
      .replaceAll(_phone, mask);

  /// Recursively masks sensitive keys and free-text values of decoded JSON.
  static Object? redactJson(Object? value) => switch (value) {
    final Map<Object?, Object?> map => {
      for (final entry in map.entries)
        '${entry.key}': isSensitiveKey('${entry.key}')
            ? mask
            : redactJson(entry.value),
    },
    final List<Object?> list => [for (final item in list) redactJson(item)],
    final String text => redactText(text),
    _ => value,
  };
}
