abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// Horizontal page padding.
  static const screenGutter = lg;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;

  /// Default corner radius in kids mode.
  static const xl = 20.0;
  static const pill = 999.0;
}

/// Sizes that must not scale with the screen (never use `.w` on them).
abstract final class AppSizes {
  static const minTapTarget = 48.0;
  static const kidsMinTapTarget = 56.0;

  static const iconSm = 16.0;
  static const iconMd = 24.0;
  static const iconLg = 32.0;
}
