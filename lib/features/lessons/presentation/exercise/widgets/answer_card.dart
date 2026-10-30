import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:flutter/material.dart';

/// Where an answer stands: chosen or not, then marked after checking.
enum AnswerLook {
  idle,
  selected,

  /// The right answer, chosen or not.
  correct,

  /// The learner's wrong answer.
  wrong,

  /// Neither, once the answer is in.
  dimmed;

  ChoiceMark? get mark => switch (this) {
    AnswerLook.correct => ChoiceMark.correct,
    AnswerLook.wrong => ChoiceMark.wrong,
    _ => null,
  };
}

/// An answer's card: the shared choice surface, with press feedback and the
/// marks of checking. Colors are never alone: the [AnswerMark] says the same.
class AnswerCard extends StatelessWidget {
  const AnswerCard({
    required this.look,
    required this.onTap,
    required this.child,
    required this.radius,
    this.semanticLabel,
    super.key,
  });

  final AnswerLook look;

  /// Null once the answer is in.
  final VoidCallback? onTap;
  final Widget child;
  final double radius;

  /// Replaces what screen readers would read from [child].
  final String? semanticLabel;

  static const _dimmed = .5;

  @override
  Widget build(BuildContext context) => PressScale(
    enabled: onTap != null,
    child: AnimatedOpacity(
      opacity: look == AnswerLook.dimmed ? _dimmed : 1,
      duration: AppMotion.resolve(context, AppMotion.quick),
      child: ChoiceSurface(
        selected: look == AnswerLook.selected || look == AnswerLook.wrong,
        mark: look.mark,
        radius: radius,
        semanticLabel: semanticLabel,
        onTap: onTap,
        child: child,
      ),
    ),
  );
}

/// The mark of an answer: an empty ring, a check when chosen, then a check or a
/// cross after checking.
class AnswerMark extends StatelessWidget {
  const AnswerMark({
    required this.look,
    this.showRing = true,
    this.size = _size,
    super.key,
  });

  final AnswerLook look;

  /// False for a picture, which shows a mark only when it has one.
  final bool showRing;
  final double size;

  static const _size = 22.0;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ChoiceCheck(
      selected: look == AnswerLook.selected,
      mark: look.mark,
      showRing: showRing,
      size: size,
    ),
  );
}

/// A text answer: its English text, left to right in any app language, and its
/// mark at the end. Grows for long options.
class TextAnswer extends StatelessWidget {
  const TextAnswer({
    required this.text,
    required this.look,
    required this.onTap,
    super.key,
  });

  final String text;
  final AnswerLook look;
  final VoidCallback? onTap;

  static const _minHeight = 56.0;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: AnswerCard(
      look: look,
      onTap: onTap,
      radius: AppRadius.md,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  locale: const Locale('en'),
                  style: context.texts.body.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AnswerMark(look: look),
            ],
          ),
        ),
      ),
    ),
  );
}
