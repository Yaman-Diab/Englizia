import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

abstract final class AppFonts {
  /// Readex Pro: UI and content, one family for Arabic and Latin so a
  /// sentence and its translation match in height and weight.
  static const primary = 'ReadexPro';

  /// Andika: letters and words in kids mode (single-storey a and g).
  static const kids = 'Andika';
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
    required this.button,
  });

  factory AppTextStyles.build({required Color color, required bool isArabic}) {
    TextStyle style(
      double size,
      double lineHeight,
      FontWeight weight, {
      bool runningText = false,
    }) {
      var height = lineHeight / size;
      // Arabic running text needs at least 1.7 for diacritics and descenders.
      if (isArabic && runningText && height < _arabicMinHeight) {
        height = _arabicMinHeight;
      }
      return TextStyle(
        fontFamily: AppFonts.primary,
        fontSize: size.sp,
        height: height,
        fontWeight: weight,
        color: color,
        leadingDistribution: TextLeadingDistribution.even,
      );
    }

    return AppTextStyles(
      display: style(28, 34, FontWeight.w600),
      title: style(22, 30, FontWeight.w600),
      reading: style(20, 36, FontWeight.w400, runningText: true),
      body: style(16, 26, FontWeight.w400, runningText: true),
      bodyStrong: style(16, 26, FontWeight.w600, runningText: true),
      caption: style(13, 20, FontWeight.w400, runningText: true),
      button: style(16, 24, FontWeight.w600),
    );
  }

  static const _arabicMinHeight = 1.7;

  /// Screen titles. 28/34, 600.
  final TextStyle display;

  /// Card titles. 22/30, 600.
  final TextStyle title;

  /// English text inside the interactive reader. 20/36, 400.
  final TextStyle reading;

  /// UI text, instructions, explanations. 16/26, 400.
  final TextStyle body;
  final TextStyle bodyStrong;

  /// Labels and secondary info. 13/20, 400.
  final TextStyle caption;

  /// Buttons. 16, 600.
  final TextStyle button;

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
    labelMedium: caption.copyWith(fontWeight: FontWeight.w600),
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
    TextStyle? button,
  }) => AppTextStyles(
    display: display ?? this.display,
    title: title ?? this.title,
    reading: reading ?? this.reading,
    body: body ?? this.body,
    bodyStrong: bodyStrong ?? this.bodyStrong,
    caption: caption ?? this.caption,
    button: button ?? this.button,
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
      button: TextStyle.lerp(button, other.button, t)!,
    );
  }
}
