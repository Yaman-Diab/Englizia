import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/mascot/mascot_palette.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The guide peeking from behind an open envelope, holding the letter's edge
/// (design "Check Email"). Plays once: the envelope lands with a small
/// bounce, the letter slides up, the guide peeks out; under reduce motion it
/// is simply there. Decorative: the title beside it carries the meaning.
class MailScene extends StatelessWidget {
  const MailScene({super.key});

  static const _width = 160.0;
  static const _height = 144.0;
  static const _guideSize = 80.0;
  static const _guideStart = 78.0;

  /// How far each layer travels to its place.
  static const _dropFrom = -56.0;
  static const _letterFrom = 44.0;
  static const _peekFrom = 30.0;

  /// The letter is white in both themes, like paper.
  static const _paper = '#FFFFFF';

  /// How strong the letter's lines and the envelope's folds are drawn.
  static const _lineOpacity = .35;
  static const _foldOpacity = .55;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brightness = Theme.of(context).brightness;
    final palette = MascotPalette.of(brightness);
    final reduce = AppMotion.reduceMotion(context);
    final body = _hex(colors.primary.fill);
    final strong = _hex(colors.primaryStrong);
    final lining = _hex(colors.primary.surface);
    final hand = _hex(palette.arm);
    final rim = switch (palette.outline) {
      final outline? => 'stroke="${_hex(outline)}" stroke-width="2.5"',
      null => '',
    };

    Widget layer(String shapes) => Positioned.fill(
      child: SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 144">'
        '$shapes</svg>',
      ),
    );

    Widget drop(Widget child) => reduce
        ? child
        : child
              .animate()
              .fadeIn(duration: AppMotion.fast, curve: AppMotion.out)
              .moveY(
                begin: _dropFrom,
                end: 0,
                duration: AppMotion.slow,
                curve: AppMotion.bounce,
              );

    Widget peek(Widget child) => reduce
        ? child
        : child
              .animate(delay: MailSceneEntrance.guide)
              .fadeIn(duration: AppMotion.quick, curve: AppMotion.out)
              .moveY(
                begin: _peekFrom,
                end: 0,
                duration: AppMotion.fast,
                curve: AppMotion.smoothOut,
              );

    final letter = layer(
      '<rect x="24" y="18" width="72" height="106" rx="5" fill="$_paper" '
      'stroke="$body" stroke-width="2"/>'
      '<path d="M35 31 H85 M35 40 H72" fill="none" stroke="$body" '
      'stroke-opacity="$_lineOpacity" stroke-width="3.5" '
      'stroke-linecap="round"/>'
      '<rect x="35" y="49" width="34" height="10" rx="5" fill="$strong"/>',
    );

    return ExcludeSemantics(
      child: SizedBox(
        width: _width,
        height: _height,
        // Art, not layout: the scene looks the same in Arabic.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: peek(
                  const Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PositionedDirectional(
                        start: _guideStart,
                        top: 0,
                        child: Mascot(size: _guideSize, animate: false),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: drop(
                  Stack(
                    children: [
                      layer(
                        '<rect x="8" y="60" width="134" height="80" rx="8" '
                        'fill="$body"/>'
                        '<rect x="14" y="64" width="122" height="72" rx="4" '
                        'fill="$lining"/>',
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: drop(
                  reduce
                      ? Stack(children: [letter])
                      : Stack(children: [letter])
                            .animate(delay: MailSceneEntrance.letter)
                            .moveY(
                              begin: _letterFrom,
                              end: 0,
                              duration: AppMotion.fast,
                              curve: AppMotion.out,
                            ),
                ),
              ),
              Positioned.fill(
                child: peek(
                  Stack(
                    children: [
                      layer(
                        '<circle cx="96" cy="41" r="6.5" fill="$hand" $rim/>',
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: drop(
                  Stack(
                    children: [
                      layer(
                        '<path d="M8 66 L75 102 L142 66 V132 Q142 140 134 140 '
                        'H16 Q8 140 8 132 Z" fill="$body"/>'
                        '<path d="M13 136 L60 104 M137 136 L90 104" '
                        'fill="none" stroke="$strong" '
                        'stroke-opacity="$_foldOpacity" stroke-width="2" '
                        'stroke-linecap="round"/>',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
