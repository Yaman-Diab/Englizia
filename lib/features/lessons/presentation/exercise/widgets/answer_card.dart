import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
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
  dimmed,
}

/// An answer's card: its border, surface and press feedback, around the
/// caller's content. A radio for screen readers. Colors are never alone: the
/// [AnswerMark] carries the same news.
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
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = AppMotion.resolve(context, AppMotion.quick);
    final (Color border, double width, Color surface) = switch (look) {
      AnswerLook.selected => (
        colors.primaryStrong,
        2.0,
        colors.primary.surface,
      ),
      AnswerLook.correct => (colors.success.fill, 2.0, colors.success.surface),
      AnswerLook.wrong => (colors.error.fill, 2.0, colors.error.surface),
      _ => (colors.border, 1.0, colors.surface),
    };
    return MergeSemantics(
      child: Semantics(
        checked: look == AnswerLook.selected || look == AnswerLook.wrong,
        inMutuallyExclusiveGroup: true,
        label: semanticLabel,
        child: PressScale(
          enabled: onTap != null,
          child: AnimatedOpacity(
            opacity: look == AnswerLook.dimmed ? _dimmed : 1,
            duration: duration,
            child: AnimatedContainer(
              duration: duration,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: border, width: width),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The mark of an answer: an empty ring, a check when chosen, then a check or a
/// cross after checking. It pops in with a small overshoot.
class AnswerMark extends StatelessWidget {
  const AnswerMark({
    required this.look,
    this.showRing = true,
    this.size = 22,
    super.key,
  });

  final AnswerLook look;

  /// False for a picture, which shows a mark only when it has one.
  final bool showRing;
  final double size;

  static const _iconShare = .64;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = AppMotion.resolve(context, AppMotion.quick);
    final Color? fill = switch (look) {
      AnswerLook.selected => colors.primaryStrong,
      AnswerLook.correct => colors.success.fill,
      AnswerLook.wrong => colors.error.fill,
      _ => null,
    };
    final AppIcon icon = look == AnswerLook.wrong
        ? AppIcon.cross
        : AppIcon.check;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showRing)
              AnimatedContainer(
                duration: duration,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: fill ?? colors.border, width: 1.5),
                ),
              ),
            AnimatedScale(
              scale: fill == null ? 0 : 1,
              duration: duration,
              curve: AppMotion.bounce,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: AppIconView(
                  icon,
                  size: size * _iconShare,
                  color: colors.surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
