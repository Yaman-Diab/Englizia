import 'package:englizia/core/design_system/app_palette.dart';
import 'package:flutter/material.dart';

/// One status role from the identity doc, split by use:
/// - [fill]: icons, option borders, progress, large areas (≥3:1).
/// - [text]: any text in the role color, e.g. "✓ صحيح" (≥4.5:1).
/// - [surface]: light background that [text] is written on.
///
/// A state is never conveyed by color alone — always with an icon and text.
@immutable
final class ToneColors {
  const ToneColors({
    required this.fill,
    required this.text,
    required this.surface,
  });

  final Color fill;
  final Color text;
  final Color surface;

  static ToneColors lerp(ToneColors a, ToneColors b, double t) => ToneColors(
    fill: Color.lerp(a.fill, b.fill, t)!,
    text: Color.lerp(a.text, b.text, t)!,
    surface: Color.lerp(a.surface, b.surface, t)!,
  );
}

/// Interactive reader + video caption tokens.
@immutable
final class ReaderColors {
  const ReaderColors({
    required this.karaokeBackground,
    required this.sentenceBand,
    required this.tappableUnderline,
    required this.selectedWord,
  });

  /// KARAOKE_BG — behind the word being spoken (text stays textPrimary, bold).
  final Color karaokeBackground;

  /// SENTENCE_BAND — behind the current sentence.
  final Color sentenceBand;

  /// TAPPABLE_UNDERLINE — dotted, 2px, under tappable words.
  final Color tappableUnderline;

  /// Selected word and every word of its (possibly non-adjacent) span, bold.
  final Color selectedWord;

  /// Captions sit on video, so they are identical in light and dark.
  Color get captionEnglish => AppPalette.white;
  Color get captionArabic => AppPalette.yellow300;
  Color get captionBackground => AppPalette.captionScrim;

  static ReaderColors lerp(
    ReaderColors a,
    ReaderColors b,
    double t,
  ) => ReaderColors(
    karaokeBackground: Color.lerp(a.karaokeBackground, b.karaokeBackground, t)!,
    sentenceBand: Color.lerp(a.sentenceBand, b.sentenceBand, t)!,
    tappableUnderline: Color.lerp(a.tappableUnderline, b.tappableUnderline, t)!,
    selectedWord: Color.lerp(a.selectedWord, b.selectedWord, t)!,
  );
}

/// Semantic tokens of "الهوية البصرية v2". Read with `context.colors`.
///
/// Role meanings are fixed: [ai] (violet) is only for AI features; [reward]
/// (amber) is XP, achievements, the save star and kids' stars; [streak] is
/// only the streak and the daily challenge.
@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.primary,
    required this.primaryStrong,
    required this.onPrimaryStrong,
    required this.success,
    required this.streak,
    required this.reward,
    required this.ai,
    required this.error,
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.background,
    required this.surface,
    required this.border,
    required this.reader,
  });

  /// PRIMARY / PRIMARY_TEXT / PRIMARY_SURFACE — navigation, track progress,
  /// selected option, links (text).
  final ToneColors primary;

  /// PRIMARY_STRONG — button backgrounds and selected words.
  final Color primaryStrong;
  final Color onPrimaryStrong;

  final ToneColors success;
  final ToneColors streak;
  final ToneColors reward;
  final ToneColors ai;
  final ToneColors error;

  /// Listening and information: audio buttons, hints, info messages.
  final ToneColors info;

  final Color textPrimary;
  final Color textSecondary;
  final Color background;
  final Color surface;
  final Color border;

  final ReaderColors reader;

  static const light = AppSemanticColors(
    primary: ToneColors(
      fill: AppPalette.blue500,
      text: AppPalette.blue700,
      surface: AppPalette.blue100,
    ),
    primaryStrong: AppPalette.blue600,
    onPrimaryStrong: AppPalette.white,
    success: ToneColors(
      fill: AppPalette.green500,
      text: AppPalette.green700,
      surface: AppPalette.green100,
    ),
    streak: ToneColors(
      fill: AppPalette.orange500,
      text: AppPalette.orange700,
      surface: AppPalette.orange100,
    ),
    reward: ToneColors(
      fill: AppPalette.amber500,
      text: AppPalette.amber700,
      surface: AppPalette.amber100,
    ),
    ai: ToneColors(
      fill: AppPalette.violet500,
      text: AppPalette.violet700,
      surface: AppPalette.violet100,
    ),
    error: ToneColors(
      fill: AppPalette.red500,
      text: AppPalette.red700,
      surface: AppPalette.red100,
    ),
    info: ToneColors(
      fill: AppPalette.cyan500,
      text: AppPalette.cyan700,
      surface: AppPalette.cyan100,
    ),
    textPrimary: AppPalette.slate800,
    textSecondary: AppPalette.slate500,
    background: AppPalette.slate50,
    surface: AppPalette.white,
    border: AppPalette.slate200,
    reader: ReaderColors(
      karaokeBackground: AppPalette.blue200,
      sentenceBand: AppPalette.blue50,
      tappableUnderline: AppPalette.blue500,
      selectedWord: AppPalette.blue600,
    ),
  );

  /// Dark neutrals, primary text, error and success follow the designs' token
  /// table; info stays cyan like its light role (the table's blue info
  /// conflicts with the designs' own note that info is cyan).
  static const dark = AppSemanticColors(
    primary: ToneColors(
      fill: AppPalette.blue400,
      text: AppPalette.sky300,
      surface: AppPalette.blue900,
    ),
    // v2: the button background is #2563EB in both modes.
    primaryStrong: AppPalette.blue600,
    onPrimaryStrong: AppPalette.white,
    success: ToneColors(
      fill: AppPalette.mint400,
      text: AppPalette.mint300,
      surface: AppPalette.green900,
    ),
    streak: ToneColors(
      fill: AppPalette.orange400,
      text: AppPalette.orange300,
      surface: AppPalette.orange900,
    ),
    reward: ToneColors(
      fill: AppPalette.amber400,
      text: AppPalette.amber300,
      surface: AppPalette.amber900,
    ),
    ai: ToneColors(
      fill: AppPalette.violet400,
      text: AppPalette.violet300,
      surface: AppPalette.violet900,
    ),
    error: ToneColors(
      fill: AppPalette.coral400,
      text: AppPalette.coral200,
      surface: AppPalette.coral950,
    ),
    info: ToneColors(
      fill: AppPalette.cyan400,
      text: AppPalette.cyan300,
      surface: AppPalette.cyan900,
    ),
    textPrimary: AppPalette.night100,
    textSecondary: AppPalette.night300,
    background: AppPalette.night950,
    surface: AppPalette.night900,
    border: AppPalette.night500,
    reader: ReaderColors(
      karaokeBackground: AppPalette.blue900,
      sentenceBand: AppPalette.blue950,
      tappableUnderline: AppPalette.blue400,
      selectedWord: AppPalette.blue400,
    ),
  );

  @override
  AppSemanticColors copyWith({
    ToneColors? primary,
    Color? primaryStrong,
    Color? onPrimaryStrong,
    ToneColors? success,
    ToneColors? streak,
    ToneColors? reward,
    ToneColors? ai,
    ToneColors? error,
    ToneColors? info,
    Color? textPrimary,
    Color? textSecondary,
    Color? background,
    Color? surface,
    Color? border,
    ReaderColors? reader,
  }) => AppSemanticColors(
    primary: primary ?? this.primary,
    primaryStrong: primaryStrong ?? this.primaryStrong,
    onPrimaryStrong: onPrimaryStrong ?? this.onPrimaryStrong,
    success: success ?? this.success,
    streak: streak ?? this.streak,
    reward: reward ?? this.reward,
    ai: ai ?? this.ai,
    error: error ?? this.error,
    info: info ?? this.info,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    reader: reader ?? this.reader,
  );

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      primary: ToneColors.lerp(primary, other.primary, t),
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      onPrimaryStrong: Color.lerp(onPrimaryStrong, other.onPrimaryStrong, t)!,
      success: ToneColors.lerp(success, other.success, t),
      streak: ToneColors.lerp(streak, other.streak, t),
      reward: ToneColors.lerp(reward, other.reward, t),
      ai: ToneColors.lerp(ai, other.ai, t),
      error: ToneColors.lerp(error, other.error, t),
      info: ToneColors.lerp(info, other.info, t),
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      reader: ReaderColors.lerp(reader, other.reader, t),
    );
  }
}
