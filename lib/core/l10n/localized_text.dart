import 'package:equatable/equatable.dart';

/// Text the server sends in both languages, `{ "ar": "…", "en": "…" }`.
/// Arabic is the fallback, as it is for the interface.
final class LocalizedText extends Equatable {
  const LocalizedText({required this.ar, this.en = ''});

  final String ar;
  final String en;

  /// The text for [languageCode], or the other language when it is missing.
  String of(String languageCode) {
    if (languageCode == 'en' && en.isNotEmpty) return en;
    return ar.isNotEmpty ? ar : en;
  }

  @override
  List<Object?> get props => [ar, en];
}
