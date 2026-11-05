import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/stone.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:flutter/material.dart';

/// A stone's small card (bubble §3.1, D19): done «أعد», locked «يُفتح بعد
/// «…»», Emar's open stone «ابدأ», and the current stone while the review
/// comes first «يُفتح بعد «راجع اليوم»». It grows out of its stone.
///
/// Place it in [place]'s rect (start, top, width and height) with the same
/// [above]: the card keeps to that rect's edge by its stone, and the rest of
/// the rect lets taps through.
///
/// ASSUMPTION(design): kids get no card, Emar's open stone «ابدأ», the
/// current stone behind the review «يُفتح بعد «راجع اليوم»», «أعد» replays
/// (D19; bubble A4, A6, A8, A10).
class StoneCard extends StatelessWidget {
  const StoneCard({
    required this.lesson,
    required this.index,
    required this.state,
    required this.lockedAfter,
    required this.reviewFirst,
    required this.onReplay,
    required this.onStart,
    this.above = false,
    this.originX,
    super.key,
  });

  final HomeLesson lesson;
  final int index;
  final StoneState state;

  /// The lesson to finish first, for «يُفتح بعد «…»»; null for the unit's
  /// review, which opens «بعد إكمال الدروس».
  final String? lockedAfter;
  final bool reviewFirst;
  final VoidCallback onReplay;
  final VoidCallback onStart;

  /// It stands above its stone (a stone below the bubble's gap).
  final bool above;

  /// The stone's centre from the card's left in the right-to-left layout;
  /// the card grows from there (its middle when null).
  final double? originX;

  static const width = 224.0;

  /// The room [place] gives the card: more than it needs at large text.
  static const box = 300.0;

  /// The card's rect beside [stone] (its centre), kept 12 inside the frame
  /// (map §12): under it, or [above] it for a stone below the gap; [last]
  /// for the lighthouse, which stands taller.
  static Rect place({
    required Offset stone,
    required bool last,
    required bool above,
    required MapFrame frame,
  }) {
    final reach = (last ? 56.0 : 30.0) + 10;
    final min = frame.fromEnd(12);
    final max = frame.fromStart(width + 12);
    final left = (stone.dx - width / 2).clamp(min, max < min ? min : max);
    return above
        ? Rect.fromLTRB(
            left,
            stone.dy - reach - box,
            left + width,
            stone.dy - reach,
          )
        : Rect.fromLTWH(left, stone.dy + reach, width, box);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final done = state == StoneState.done;
    final waitsForReview = reviewFirst && state == StoneState.current;
    final lockLine = waitsForReview
        ? 'home_opens_after_lesson'.tr(args: ['home_review_title'.tr()])
        : state == StoneState.locked
        ? (lesson.kind == LessonKind.unitReview || lockedAfter == null
              ? 'unit_review_after'.tr()
              : 'home_opens_after_lesson'.tr(args: [lockedAfter!]))
        : null;
    final action = done
        ? (label: 'unit_redo'.tr(), onPressed: onReplay)
        : state == StoneState.open
        ? (label: 'unit_start'.tr(), onPressed: onStart)
        : null;
    final card = Container(
      width: width,
      // The button's target reaches into the bottom padding by its slack.
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        14,
        16,
        action == null ? 14 : 14 - _CardButton.slack,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: context.scheme.outline),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: context.scheme.shadow.withValues(alpha: .12),
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            done
                ? 'unit_status_done'.tr()
                : 'unit_lesson_number'.tr(args: ['${index + 1}']),
            style: texts.caption.copyWith(
              fontSize: 12,
              height: 18 / 12,
              color: colors.textSecondary,
            ),
          ),
          Text(lesson.title, style: texts.bodyStrong.copyWith(height: 24 / 16)),
          Text(
            lessonMeta(lesson),
            style: texts.caption.copyWith(
              height: 20 / 13,
              color: colors.textSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _CardButton(label: action.label, onPressed: action.onPressed),
          ],
          if (lockLine != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                StoneIcon(
                  AppIcon.lock,
                  color: colors.textPrimary,
                  size: 14,
                  stroke: 2.2,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lockLine,
                    style: texts.captionStrong.copyWith(
                      height: 20 / 13,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    final reduce = AppMotion.reduceMotion(context);
    final fromStart = width - (originX ?? width / 2);
    final origin = AlignmentDirectional(
      2 * fromStart / width - 1,
      above ? 1 : -1,
    ).resolve(Directionality.of(context));
    return Align(
      alignment: above
          ? AlignmentDirectional.bottomStart
          : AlignmentDirectional.topStart,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: lesson.title,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(lesson.id),
          tween: Tween(begin: 0, end: 1),
          duration: reduce ? AppMotion.quick : AppMotion.homeCardPop,
          curve: reduce ? AppMotion.linear : AppMotion.homeEmphasis,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: reduce ? 1 : lerpDouble(AppMotion.homeCardFrom, 1, t)!,
              alignment: origin,
              child: child,
            ),
          ),
          child: card,
        ),
      ),
    );
  }
}

/// «أعد» / «ابدأ»: a secondary button 44 high on a 48 target.
class _CardButton extends StatelessWidget {
  const _CardButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const _height = 44.0;

  /// The target's extra height above and below the drawn button.
  static const slack = (48.0 - _height) / 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: slack),
          child: PressScale(
            scale: AppMotion.scaleSmall,
            child: Container(
              height: _height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: context.scheme.outline, width: 1.5),
                borderRadius: BorderRadius.circular(_height / 2),
              ),
              child: Text(
                label,
                style: context.texts.button.copyWith(
                  fontSize: 14,
                  height: 1,
                  color: colors.primary.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
