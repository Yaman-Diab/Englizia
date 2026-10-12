import 'package:englizia/core/design_system/app_palette.dart';
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Light and dark themes. Call inside `ScreenUtilInit` (text uses `.sp`).
abstract final class AppTheme {
  /// Reference screen for `flutter_screenutil`.
  static const designSize = Size(375, 812);

  static ThemeData light({required bool isArabic}) =>
      _build(AppSemanticColors.light, _lightScheme, isArabic: isArabic);

  static ThemeData dark({required bool isArabic}) =>
      _build(AppSemanticColors.dark, _darkScheme, isArabic: isArabic);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.blue600,
    onPrimary: AppPalette.white,
    primaryContainer: AppPalette.blue100,
    onPrimaryContainer: AppPalette.blue900,
    secondary: AppPalette.cyan700,
    onSecondary: AppPalette.white,
    secondaryContainer: AppPalette.cyan100,
    onSecondaryContainer: AppPalette.cyan900,
    tertiary: AppPalette.amber700,
    onTertiary: AppPalette.white,
    tertiaryContainer: AppPalette.amber100,
    onTertiaryContainer: AppPalette.amber900,
    error: AppPalette.red700,
    onError: AppPalette.white,
    errorContainer: AppPalette.red100,
    onErrorContainer: AppPalette.red900,
    surface: AppPalette.white,
    onSurface: AppPalette.slate800,
    onSurfaceVariant: AppPalette.slate500,
    surfaceContainerLowest: AppPalette.white,
    surfaceContainerLow: AppPalette.white,
    surfaceContainer: AppPalette.slate50,
    surfaceContainerHigh: AppPalette.slate100,
    surfaceContainerHighest: AppPalette.slate200,
    outline: AppPalette.slate500,
    outlineVariant: AppPalette.slate200,
    inverseSurface: AppPalette.slate800,
    onInverseSurface: AppPalette.slate100,
    inversePrimary: AppPalette.blue300,
    shadow: AppPalette.black,
    scrim: AppPalette.black,
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.blue400,
    onPrimary: AppPalette.slate900,
    primaryContainer: AppPalette.blue900,
    onPrimaryContainer: AppPalette.blue100,
    secondary: AppPalette.cyan300,
    onSecondary: AppPalette.slate900,
    secondaryContainer: AppPalette.cyan900,
    onSecondaryContainer: AppPalette.cyan100,
    tertiary: AppPalette.amber300,
    onTertiary: AppPalette.slate900,
    tertiaryContainer: AppPalette.amber900,
    onTertiaryContainer: AppPalette.amber100,
    error: AppPalette.red300,
    onError: AppPalette.slate900,
    errorContainer: AppPalette.red900,
    onErrorContainer: AppPalette.red100,
    surface: AppPalette.slate800,
    onSurface: AppPalette.slate100,
    onSurfaceVariant: AppPalette.slate400,
    surfaceContainerLowest: AppPalette.slate900,
    surfaceContainerLow: AppPalette.slate900,
    surfaceContainer: AppPalette.slate800,
    surfaceContainerHigh: AppPalette.slate700,
    surfaceContainerHighest: AppPalette.slate700,
    outline: AppPalette.slate500,
    outlineVariant: AppPalette.slate700,
    inverseSurface: AppPalette.slate100,
    onInverseSurface: AppPalette.slate800,
    inversePrimary: AppPalette.blue600,
    shadow: AppPalette.black,
    scrim: AppPalette.black,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(
    AppSemanticColors colors,
    ColorScheme scheme, {
    required bool isArabic,
  }) {
    final texts = AppTextStyles.build(
      color: colors.textPrimary,
      isArabic: isArabic,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const buttonMinSize = Size(AppSizes.minTapTarget, AppSizes.minTapTarget);
    const buttonPadding = EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.md,
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: texts.body.fontFamily,
      scaffoldBackgroundColor: colors.background,
      textTheme: texts.toTextTheme(),
      extensions: [colors, texts],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texts.title,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primaryStrong,
          foregroundColor: colors.onPrimaryStrong,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          textStyle: texts.button,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary.text,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          textStyle: texts.button,
          shape: buttonShape,
          side: BorderSide(color: colors.primary.fill),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary.text,
          minimumSize: buttonMinSize,
          textStyle: texts.button,
          shape: buttonShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: texts.body.copyWith(color: colors.textSecondary),
        errorStyle: texts.caption.copyWith(color: colors.error.text),
        border: inputBorder(scheme.outline),
        enabledBorder: inputBorder(scheme.outline),
        focusedBorder: inputBorder(colors.primaryStrong, 2),
        errorBorder: inputBorder(colors.error.fill),
        focusedErrorBorder: inputBorder(colors.error.fill, 2),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primary.surface,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? texts.captionStrong.copyWith(color: colors.primary.text)
              : texts.caption.copyWith(color: colors.textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.primary.text
                : colors.textSecondary,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: texts.body.copyWith(color: scheme.onInverseSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary.fill,
        linearTrackColor: colors.primary.surface,
      ),
    );
  }
}
