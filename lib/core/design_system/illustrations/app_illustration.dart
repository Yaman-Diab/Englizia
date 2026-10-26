import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Small scene illustrations from the approved designs (Claude Design
/// "Onboarding Option"), drawn in a 64×64 box and shown in a 56 circle.
/// Colors follow light and dark mode; an illustration is added when the
/// screen that uses it is built.
enum AppIllustration {
  /// A seedling in the ground: starting from zero.
  sprout,

  /// Stairs with a flag on the first step: a known starting level.
  stairs;

  String _svg(_IllustrationColors c) => switch (this) {
    sprout =>
      '<path d="M6 50 Q32 38 58 50 V64 H6 Z" fill="${c.amberDeep}"/>'
          '<circle cx="22" cy="52" r="1.6" fill="${c.amber}"/>'
          '<circle cx="40" cy="55" r="1.4" fill="${c.amber}"/>'
          '<circle cx="30" cy="58" r="1.2" fill="${c.amber}"/>'
          '<path d="M32 46 C32 40 32 35 32 28" fill="none" stroke="#2FA36B" '
          'stroke-width="3.4" stroke-linecap="round"/>'
          '<path d="M32 35 C23.5 35 18.5 30 18.5 23.5 C26 23.5 31 28 32 35 Z" '
          'fill="#3DBE7A"/>'
          '<path d="M32 30.5 C33 22.5 39 17.5 46.5 18 C46.5 25.5 40.5 30.5 32 '
          '30.5 Z" fill="#2FA36B"/>'
          '<path d="M23 27 Q27 29 30 33" fill="none" stroke="#2FA36B" '
          'stroke-width="1.2" stroke-linecap="round" opacity=".7"/>',
    stairs =>
      '<path d="M10 54 V32 H21 V38 H32 V44 H43 V50 H54 V54 Z" '
          'fill="${c.body}"/>'
          '<path d="M10 32 H21 M21 38 H32 M32 44 H43 M43 50 H54" fill="none" '
          'stroke="${c.belly}" stroke-width="2.4" stroke-linecap="round"/>'
          '<path d="M8 54 H56" fill="none" stroke="${c.feet}" '
          'stroke-width="2.4" stroke-linecap="round"/>'
          '<path d="M15.5 32 V13" fill="none" stroke="${c.ink}" '
          'stroke-width="2.2" stroke-linecap="round"/>'
          '<path d="M15.5 13.5 L27 17.2 L15.5 21 Z" fill="${c.amber}"/>',
  };
}

/// Draws an [AppIllustration] at [size]. Decorative: the label beside it
/// carries the meaning.
class AppIllustrationView extends StatelessWidget {
  const AppIllustrationView(this.illustration, {this.size = 56, super.key});

  final AppIllustration illustration;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors =
        (dark ? _IllustrationColors.darkMode : _IllustrationColors.lightMode)
            .withInk(context.colors.textPrimary);
    return ExcludeSemantics(
      child: SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
        '${illustration._svg(colors)}</svg>',
        width: size,
        height: size,
      ),
    );
  }
}

/// The designs' illustration colors (CSS `--ob-m-*`, same names), as SVG hex strings.
final class _IllustrationColors {
  const _IllustrationColors({
    required this.body,
    required this.belly,
    required this.feet,
    required this.amber,
    required this.amberDeep,
    this.ink = '#0F1A2A',
  });

  final String body;
  final String belly;
  final String feet;
  final String amber;
  final String amberDeep;
  final String ink;

  static const lightMode = _IllustrationColors(
    body: '#2F6FE0',
    belly: '#5D91EC',
    feet: '#1A52B8',
    amber: '#F2A93B',
    amberDeep: '#E0962A',
  );

  static const darkMode = _IllustrationColors(
    body: '#3D7BEA',
    belly: '#6B9DF0',
    feet: '#2560C9',
    amber: '#F5B54E',
    amberDeep: '#E3A03A',
  );

  /// Lines drawn in the theme's text color (the flag pole).
  _IllustrationColors withInk(Color color) => _IllustrationColors(
    body: body,
    belly: belly,
    feet: feet,
    amber: amber,
    amberDeep: amberDeep,
    ink: '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
  );
}
