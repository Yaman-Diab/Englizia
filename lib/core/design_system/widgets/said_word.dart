import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/word_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A word of a sentence said aloud, which lights up in its turn once the verdict
/// is in: heard, with a line and a check, or missed, greyed with a dotted line.
class SaidWord extends StatelessWidget {
  const SaidWord({
    required this.word,
    required this.index,
    required this.heard,
    super.key,
  });

  final String word;
  final int index;
  final bool? heard;

  static const _checkSize = 14.0;
  static const _checkAbove = 15.0;
  static const _line = 2.0;

  Widget _face(BuildContext context, double t) {
    final colors = context.colors;
    final heard = this.heard;
    final color = heard == null
        ? colors.textPrimary
        : Color.lerp(
            colors.textPrimary,
            heard ? colors.success.text : colors.textSecondary,
            t,
          )!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          foregroundPainter: WordLine(
            color: heard == null
                ? Colors.transparent
                : (heard ? colors.success.fill : context.scheme.outline)
                      .withValues(alpha: t),
            dotted: heard == false,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(bottom: _line),
            child: Text(
              word,
              locale: const Locale('en'),
              style: context.texts.reading.copyWith(color: color),
            ),
          ),
        ),
        if (heard ?? false)
          PositionedDirectional(
            top: -_checkAbove + AppSpacing.xs,
            start: 0,
            end: 0,
            child: Center(
              child: Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: .6 + .4 * AppMotion.bounce.transform(t),
                  child: Icon(
                    Icons.check_rounded,
                    size: _checkSize,
                    color: colors.success.fill,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (heard == null || AppMotion.reduceMotion(context)) {
      return _face(context, 1);
    }
    return Animate(
      delay: AppMotion.stagger * 1.5 * index,
      effects: [
        CustomEffect(
          duration: AppMotion.closeUp,
          curve: AppMotion.out,
          builder: (context, value, _) => _face(context, value),
        ),
      ],
      child: const SizedBox.shrink(),
    );
  }
}
