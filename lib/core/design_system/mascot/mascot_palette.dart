import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Colors of the guide drawing. These are character art, not UI roles, so
/// they live here instead of `AppSemanticColors`; values are those of the
/// approved drawing (Claude Design `Guide.dc.html`) and of the welcome
/// screen's backdrop.
@immutable
final class MascotPalette {
  const MascotPalette({
    required this.body,
    required this.arm,
    required this.belly,
    required this.feet,
    required this.scarf,
    required this.scarfDeep,
    required this.ink,
    required this.highlight,
    required this.blush,
    required this.spark,
    required this.outline,
    required this.shadow,
    required this.stageRing,
    required this.stageFill,
  });

  final Color body;
  final Color arm;
  final Color belly;
  final Color feet;
  final Color scarf;
  final Color scarfDeep;

  /// Eyes, brows, mouth.
  final Color ink;

  /// Eye highlights and the white of a looking eye.
  final Color highlight;

  /// Cheeks and tongue.
  final Color blush;

  /// Sparkles and the wave marks.
  final Color spark;

  /// Thin light rim that keeps the shape readable on dark backgrounds.
  final Color? outline;

  /// Ground shadow, including its opacity.
  final Color shadow;

  /// The circle behind the guide on hero screens.
  final Color stageRing;
  final Color stageFill;

  static const light = MascotPalette(
    body: Color(0xFF5A97F2),
    arm: Color(0xFF4A89EE),
    belly: Color(0xFFBCD6FC),
    feet: Color(0xFF3F7FE6),
    scarf: Color(0xFFF2A93B),
    scarfDeep: Color(0xFFD98A1F),
    ink: Color(0xFF0B1B3A),
    highlight: Color(0xFFFFFFFF),
    blush: Color(0xFFF6A28C),
    spark: Color(0xFFF2A93B),
    outline: null,
    shadow: Color(0x240B1B3A),
    stageRing: Color(0xFFDCE6F7),
    stageFill: Color(0xFFE6EEFB),
  );

  static const dark = MascotPalette(
    body: Color(0xFF5A97F2),
    arm: Color(0xFF4A89EE),
    belly: Color(0xFFBCD6FC),
    feet: Color(0xFF3F7FE6),
    scarf: Color(0xFFF2A93B),
    scarfDeep: Color(0xFFD98A1F),
    ink: Color(0xFF0B1B3A),
    highlight: Color(0xFFFFFFFF),
    blush: Color(0xFFF6A28C),
    spark: Color(0xFFF2A93B),
    outline: Color(0xFFCFE1FF),
    shadow: Color(0x59000000),
    stageRing: Color(0xFF1C2944),
    stageFill: Color(0xFF16213A),
  );

  static MascotPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
