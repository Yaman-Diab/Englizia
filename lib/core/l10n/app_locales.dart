import 'package:flutter/widgets.dart';

abstract final class AppLocales {
  static const arabic = Locale('ar');
  static const english = Locale('en');

  static const supported = [arabic, english];

  /// Primary audience; used when the device language is unsupported.
  static const fallback = arabic;

  static const translationsPath = 'assets/translations';
}

/// Current UI language for code without a `BuildContext` (HTTP headers).
/// The `App` widget keeps it in sync with the active locale.
final class CurrentLanguage {
  String code = AppLocales.fallback.languageCode;
}
