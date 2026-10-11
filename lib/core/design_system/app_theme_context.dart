import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Both extensions are always registered by `AppTheme`; a missing one is a
/// setup bug and fails fast.
extension AppThemeContext on BuildContext {
  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>()!;

  AppTextStyles get texts => Theme.of(this).extension<AppTextStyles>()!;

  ColorScheme get scheme => Theme.of(this).colorScheme;
}
