import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fonts come from `google_fonts`, loaded from the files bundled in
/// `assets/fonts/` (runtime fetching is disabled in `main.dart`).
///
/// google_fonts gives every weight its own family, so never change
/// `fontWeight` with `copyWith`: pick the role that already has it.
abstract final class AppFonts {
  /// Readex Pro: UI and content, one family for Arabic and Latin so a
  /// sentence and its translation match in height and weight.
  static TextStyle primary(TextStyle style) =>
      GoogleFonts.readexPro(textStyle: style);

  /// Andika: letters and words in kids mode (single-storey a and g).
  static TextStyle kids(TextStyle style) =>
      GoogleFonts.andika(textStyle: style);
}

/// Type roles from "الهوية البصرية v2" (size/line-height in logical px).
/// Read with `context.texts`; recolor with `.copyWith(color: ...)`.
///
/// Must be built inside `ScreenUtilInit` so `.sp` uses the real screen.
@immutable
final class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.display,
    required this.title,
    required this.reading,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.captionStrong,
    required this.button,
    required this.kidsGreeting,
    required this.kidsWord,
    required this.kidsCard,
    required this.runningMinHeight,
  });

  factory AppTextStyles.build({required Color color, required bool isArabic}) {
    TextStyle style(
      double size,
      double lineHeight,
      FontWeight weight, {
      bool runningText = false,
      bool kids = false,
    }) {
      var height = lineHeight / size;
      // Arabic running text needs at least 1.7 for diacritics and descenders.
      if (isArabic && runningText && height < _arabicMinHeight) {
        height = _arabicMinHeight;
      }
      final base = TextStyle(
        fontSize: size.sp,
        height: height,
        fontWeight: weight,
        color: color,
        leadingDistribution: TextLeadingDistribution.even,
      );
      return kids ? AppFonts.kids(base) : AppFonts.primary(base);
    }

    return AppTextStyles(
      display: style(28, 34, FontWeight.w600),
      title: style(22, 30, FontWeight.w600),
      reading: style(20, 36, FontWeight.w400, runningText: true),
      body: style(16, 26, FontWeight.w400, runningText: true),
      bodyStrong: style(16, 26, FontWeight.w600, runningText: true),
      caption: style(13, 20, FontWeight.w400, runningText: true),
      captionStrong: style(13, 20, FontWeight.w600, runningText: true),
      button: style(16, 24, FontWeight.w600),
      kidsGreeting: style(35, 44, FontWeight.w600),
      kidsWord: style(50, 64, FontWeight.w700, kids: true),
      kidsCard: style(28, 40, FontWeight.w400, kids: true),
      runningMinHeight: isArabic ? _arabicMinHeight : 0,
    );
  }

  static const _arabicMinHeight = 1.7;

  /// Screen titles. 28/34, 600.
  final TextStyle display;

  /// Card titles. 22/30, 600.
  final TextStyle title;

  /// English text inside the interactive reader. 20/36, 400.
  final TextStyle reading;

  /// UI text, instructions, explanations. 16/26, 400 / 600.
  final TextStyle body;
  final TextStyle bodyStrong;

  /// Labels and secondary info. 13/20, 400 / 600.
  final TextStyle caption;
  final TextStyle captionStrong;

  /// Buttons. 16, 600.
  final TextStyle button;

  /// Kids mode: the guide's greeting to the child. 35/44, 600.
  final TextStyle kidsGreeting;

  /// Kids mode: an English word to hear and tap, in Andika. 50/64, 700.
  final TextStyle kidsWord;

  /// Kids mode: a letter or a word on a card, in Andika. 28/40, 400; a big
  /// letter takes the same role at its own size.
  final TextStyle kidsCard;

  /// The least line height of running text: Arabic's 1.7, for diacritics
  /// and descenders; none in English.
  final double runningMinHeight;

  /// [role] at a design's [size] and [line] height (logical px, as the
  /// design gives them). [running] text, which may wrap, keeps at least
  /// [runningMinHeight], so a wrapped line never clips; a single line, such
  /// as a chip, keeps the design's.
  TextStyle sized(
    TextStyle role, {
    required double size,
    required double line,
    bool running = true,
  }) {
    final design = line / size;
    return role.copyWith(
      fontSize: size,
      height: running ? math.max(design, runningMinHeight) : design,
    );
  }

  /// [sized] for [text] laid out [width] wide in [context], for a box the
  /// design sizes: the design's line while it fits one line, so the box
  /// holds it at its own size, and the running floor once it wraps (large
  /// text).
  TextStyle sizedFor(
    BuildContext context,
    TextStyle role, {
    required String text,
    required double width,
    required double size,
    required double line,
  }) {
    final one = sized(role, size: size, line: line, running: false);
    if (runningMinHeight <= line / size) return one;
    final painter = TextPainter(
      text: TextSpan(text: text, style: one),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout(maxWidth: math.max(0, width));
    final wraps = painter.computeLineMetrics().length > 1;
    painter.dispose();
    return wraps ? sized(role, size: size, line: line) : one;
  }

  /// Maps the roles onto Material's scale so stock widgets match.
  TextTheme toTextTheme() => TextTheme(
    displaySmall: display,
    headlineLarge: display,
    headlineMedium: display,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: bodyStrong,
    titleSmall: bodyStrong,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: captionStrong,
    labelSmall: caption,
  );

  @override
  AppTextStyles copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? reading,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? caption,
    TextStyle? captionStrong,
    TextStyle? button,
    TextStyle? kidsGreeting,
    TextStyle? kidsWord,
    TextStyle? kidsCard,
    double? runningMinHeight,
  }) => AppTextStyles(
    display: display ?? this.display,
    title: title ?? this.title,
    reading: reading ?? this.reading,
    body: body ?? this.body,
    bodyStrong: bodyStrong ?? this.bodyStrong,
    caption: caption ?? this.caption,
    captionStrong: captionStrong ?? this.captionStrong,
    button: button ?? this.button,
    kidsGreeting: kidsGreeting ?? this.kidsGreeting,
    kidsWord: kidsWord ?? this.kidsWord,
    kidsCard: kidsCard ?? this.kidsCard,
    runningMinHeight: runningMinHeight ?? this.runningMinHeight,
  );

  @override
  AppTextStyles lerp(AppTextStyles? other, double t) {
    if (other == null) return this;
    return AppTextStyles(
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      reading: TextStyle.lerp(reading, other.reading, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      captionStrong: TextStyle.lerp(captionStrong, other.captionStrong, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      kidsGreeting: TextStyle.lerp(kidsGreeting, other.kidsGreeting, t)!,
      kidsWord: TextStyle.lerp(kidsWord, other.kidsWord, t)!,
      kidsCard: TextStyle.lerp(kidsCard, other.kidsCard, t)!,
      runningMinHeight: lerpDouble(
        runningMinHeight,
        other.runningMinHeight,
        t,
      )!,
    );
  }
}
