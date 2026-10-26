import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Small scenes of the guide for answer cards, drawn for a 56 circle (the
/// card clips them round). They replace the designs' sprout and stairs at
/// the owner's choice. Colors follow light and dark mode; a scene is added
/// when the screen that uses it is built.
enum AppIllustration {
  /// The guide hatching from an egg, waving: starting from zero.
  hatching,

  /// The guide listening in headphones, saying "Hi": knows some English.
  listening,
}

/// Draws an [AppIllustration] at [size]. Decorative: the label beside it
/// carries the meaning.
class AppIllustrationView extends StatelessWidget {
  const AppIllustrationView(this.illustration, {this.size = _box, super.key});

  final AppIllustration illustration;
  final double size;

  /// The box the scenes are composed in; other sizes scale it.
  static const _box = 56.0;

  /// The full guide, larger than the box so its head fills the circle.
  static const _mascotSize = 84.0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scene = switch (illustration) {
      AppIllustration.hatching => [
        const Positioned(
          left: -19,
          top: -6,
          child: Mascot(size: _mascotSize, animate: false),
        ),
        Positioned.fill(child: SvgPicture.string(_eggshell(dark))),
      ],
      AppIllustration.listening => [
        const Positioned(
          left: -14,
          top: 3,
          child: Mascot(
            expression: MascotExpression.listen,
            prop: MascotProp.headphones,
            size: _mascotSize,
            animate: false,
          ),
        ),
        Positioned(
          left: 5,
          top: 8,
          width: 20,
          height: 15,
          child: SvgPicture.string(_hiBubble(context.colors.primaryStrong)),
        ),
      ],
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: FittedBox(
          child: SizedBox.square(
            dimension: _box,
            child: Stack(clipBehavior: Clip.none, children: scene),
          ),
        ),
      ),
    );
  }

  /// The lower half of a cracked shell, in the guide's amber.
  static String _eggshell(bool dark) {
    final (shell, edge, spot) = dark
        ? ('#F3EAD8', '#E3A03A', '#F5B54E')
        : ('#FFF7E8', '#E0962A', '#F2A93B');
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
        '<path d="M8 50 L14 45.5 L20 50.5 L26 45 L32 50.5 L38 45 L44 50.5 '
        'L50 45.5 L56 50 C58 56 57 61 54 66 L10 66 C7 61 6 56 8 50 Z" '
        'fill="$shell" stroke="$edge" stroke-width="1.6" '
        'stroke-linejoin="round"/>'
        '<circle cx="20" cy="57" r="2" fill="$spot"/>'
        '<circle cx="42" cy="59" r="2.4" fill="$spot"/>'
        '<circle cx="31" cy="55" r="1.4" fill="$spot"/>'
        '</svg>';
  }

  /// A small speech bubble with "Hi" drawn as strokes, so it is art and not
  /// text to translate.
  static String _hiBubble(Color fill) {
    final hex = (fill.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 15">'
        '<path d="M4 0.5 H16 A3.5 3.5 0 0 1 19.5 4 V8 A3.5 3.5 0 0 1 16 11.5 '
        'H9 L6 14.5 L6 11.5 H4 A3.5 3.5 0 0 1 0.5 8 V4 A3.5 3.5 0 0 1 4 0.5 Z" '
        'fill="#$hex"/>'
        '<path d="M6.5 3.5 V8.5 M6.5 6 H10 M10 3.5 V8.5 M13.5 5.8 V8.5" '
        'fill="none" stroke="#FFFFFF" stroke-width="1.5" '
        'stroke-linecap="round"/>'
        '<circle cx="13.5" cy="3.7" r="0.95" fill="#FFFFFF"/>'
        '</svg>';
  }
}
