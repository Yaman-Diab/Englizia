import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/ai_spark.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/kind_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// «الصندوق القابل للكسر، محادثة ذكية، 5 دقائق».
String unitLessonMeta(UnitLesson lesson) {
  final kind = lessonKindName(lesson.kind);
  final minutes = lesson.minutes;
  if (minutes == null) return kind;
  return 'unit_lesson_meta'.tr(
    namedArgs: {'kind': kind, 'minutes': 'unit_minutes'.plural(minutes)},
  );
}

/// A unit's lessons as a vertical timeline (S §6.2): a mark for each, joined
/// by a line that turns green behind what is done. Only the current lesson is
/// a card, so it is the one thing that stands out.
class UnitTimeline extends StatelessWidget {
  const UnitTimeline({
    required this.plan,
    required this.status,
    required this.available,
    required this.onOpen,
    this.settling,
    this.arrived,
    this.currentKey,
    super.key,
  });

  final UnitPlan plan;
  final UnitLessonStatus Function(int index) status;
  final bool Function(UnitLesson lesson) available;
  final ValueChanged<UnitLesson> onOpen;

  /// The lesson just completed: its mark fills and its line grows.
  final String? settling;

  /// The lesson the chain just moved on to: its card opens.
  final String? arrived;
  final GlobalKey? currentKey;

  static const _dimmed = .45;

  @override
  Widget build(BuildContext context) {
    final lessons = plan.lessons;
    return Semantics(
      label: 'unit_lessons'.tr(),
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, lesson) in lessons.indexed)
            Opacity(
              opacity: available(lesson) ? 1 : _dimmed,
              child: _LessonRow(
                number: index + 1,
                lesson: lesson,
                status: status(index),
                open: available(lesson),
                last: index == lessons.length - 1,
                book: plan.bookPages != null,
                filling: lesson.id == settling,
                arriving: lesson.id == arrived,
                cardKey: currentKey,
                onOpen: () => onOpen(lesson),
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.number,
    required this.lesson,
    required this.status,
    required this.open,
    required this.last,
    required this.book,
    required this.filling,
    required this.arriving,
    required this.cardKey,
    required this.onOpen,
  });

  final int number;
  final UnitLesson lesson;
  final UnitLessonStatus status;

  /// It can be opened now: online, or kept on the phone.
  final bool open;
  final bool last;
  final bool book;
  final bool filling;
  final bool arriving;
  final GlobalKey? cardKey;
  final VoidCallback onOpen;

  static const _rail = 40.0;
  static const _lineMin = 16.0;

  String _semantics() {
    final state = !open
        ? 'unit_status_offline'.tr()
        : switch (status) {
            UnitLessonStatus.done => 'unit_status_done'.tr(),
            UnitLessonStatus.current => 'unit_status_current'.tr(),
            UnitLessonStatus.locked => 'unit_status_locked'.tr(),
            UnitLessonStatus.open => 'unit_status_open'.tr(),
          };
    return 'unit_lesson_semantics'.tr(
      namedArgs: {
        'number': '$number',
        'title': lesson.title,
        'meta': unitLessonMeta(lesson),
        'status': state,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = status == UnitLessonStatus.current;
    final reduce = AppMotion.reduceMotion(context);
    Widget mark = _Mark(kind: lesson.kind, status: status);
    if (filling && !reduce) {
      mark = mark
          .animate()
          .scaleXY(
            begin: .6,
            end: 1.15,
            duration: AppMotion.unitMarkFill * .6,
            curve: AppMotion.out,
          )
          .then()
          .scaleXY(
            begin: 1,
            end: 1 / 1.15,
            duration: AppMotion.unitMarkFill * .4,
            curve: AppMotion.out,
          );
    }
    return Semantics(
      container: true,
      label: _semantics(),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _rail,
              child: Column(
                children: [
                  ExcludeSemantics(child: mark),
                  if (!last)
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: _lineMin),
                        child: _Line(
                          done: status == UnitLessonStatus.done,
                          growing: filling && !reduce,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  bottom: last
                      ? 0
                      : current
                      ? AppSpacing.xl - AppSpacing.xs
                      : AppSpacing.md,
                ),
                child: current
                    ? _CurrentCard(
                        key: cardKey,
                        number: number,
                        lesson: lesson,
                        book: book,
                        open: open,
                        arriving: arriving && !reduce,
                        onOpen: onOpen,
                      )
                    : _FlatRow(
                        lesson: lesson,
                        status: status,
                        book: book,
                        open: open,
                        onOpen: onOpen,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lesson's mark: its kind's icon, a check once done, ringed when current.
class _Mark extends StatelessWidget {
  const _Mark({required this.kind, required this.status});

  final LessonKind kind;
  final UnitLessonStatus status;

  static const _size = 40.0;
  static const _ring = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = status == UnitLessonStatus.done;
    final current = status == UnitLessonStatus.current;
    final duration = AppMotion.resolve(context, AppMotion.fast);
    return AnimatedContainer(
      duration: duration,
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? colors.success.fill
            : current
            ? colors.primaryStrong
            : colors.surface,
        border: done || current
            ? null
            : Border.all(color: colors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: current ? colors.primary.surface : Colors.transparent,
            spreadRadius: _ring,
          ),
        ],
      ),
      child: AppIconView(
        done ? AppIcon.check : lessonKindIcon(kind),
        size: done ? AppSizes.iconMd - 4 : AppSizes.iconMd - 2,
        color: done
            ? colors.surface
            : current
            ? colors.onPrimaryStrong
            : status == UnitLessonStatus.locked
            ? colors.textSecondary
            : colors.textPrimary,
      ),
    );
  }
}

/// The line under a mark: green below what is done, growing as it fills.
class _Line extends StatelessWidget {
  const _Line({required this.done, required this.growing});

  final bool done;
  final bool growing;

  static const _width = 2.0;
  static const _faint = .5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget green = ColoredBox(color: colors.success.fill);
    if (growing) {
      green = green.animate().scaleY(
        begin: 0,
        end: 1,
        alignment: Alignment.topCenter,
        delay: AppMotion.unitLineDelay,
        duration: AppMotion.unitLineGrow,
        curve: AppMotion.inOut,
      );
    }
    return Center(
      child: SizedBox(
        width: _width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: _faint,
              child: ColoredBox(color: colors.border),
            ),
            if (done) green,
          ],
        ),
      ),
    );
  }
}

/// The meta line: kind and length, ✦ for the AI's conversations, a lock.
class _Meta extends StatelessWidget {
  const _Meta({required this.lesson, this.locked = false});

  final UnitLesson lesson;
  final bool locked;

  static const _spark = 12.0;
  static const _lock = 13.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        if (lesson.kind == LessonKind.conversation) ...[
          const AiSpark(size: _spark),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            unitLessonMeta(lesson),
            style: context.texts.caption.copyWith(color: colors.textSecondary),
          ),
        ),
        if (locked) ...[
          const SizedBox(width: AppSpacing.xs + 2),
          AppIconView(AppIcon.lock, size: _lock, color: colors.textSecondary),
        ],
      ],
    );
  }
}

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({
    required this.number,
    required this.lesson,
    required this.book,
    required this.open,
    required this.arriving,
    required this.onOpen,
    super.key,
  });

  final int number;
  final UnitLesson lesson;
  final bool book;
  final bool open;
  final bool arriving;
  final VoidCallback onOpen;

  static const _barHeight = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final resume = lesson.resume;
    final page = lesson.page;
    Widget button = AppButton(
      label: lesson.isReview
          ? 'unit_start_review'.tr()
          : resume != null
          ? 'unit_continue'.tr()
          : 'unit_start'.tr(),
      onPressed: open ? onOpen : null,
    );
    if (arriving) {
      button = button
          .animate(delay: AppMotion.unitButtonDelay)
          .fadeIn(duration: AppMotion.unitButtonIn, curve: AppMotion.out)
          .moveY(begin: -AppMotion.distanceBase, end: 0, curve: AppMotion.out);
    }
    Widget card = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.primary.surface,
        border: Border.all(color: colors.primaryStrong, width: 2),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(
              lesson.isReview
                  ? 'lesson_kind_unit_review'.tr()
                  : 'unit_lesson_number'.tr(args: ['$number']),
              style: texts.captionStrong.copyWith(color: colors.primary.text),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          ExcludeSemantics(
            child: Text(
              lesson.title,
              style: texts.bodyStrong.copyWith(fontSize: 18, height: 28 / 18),
            ),
          ),
          ExcludeSemantics(child: _Meta(lesson: lesson)),
          if (book && page != null)
            ExcludeSemantics(
              child: Text(
                'unit_page'.tr(args: ['$page']),
                style: texts.caption.copyWith(color: colors.textSecondary),
              ),
            ),
          if (resume != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            ExcludeSemantics(
              child: Container(
                height: _barHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                ),
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: resume.share,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryStrong,
                      borderRadius: BorderRadius.circular(_barHeight / 2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'unit_stopped_at'.tr(args: ['${resume.question}']),
              style: texts.caption.copyWith(color: colors.textPrimary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          button,
        ],
      ),
    );
    if (arriving) {
      card = card
          .animate()
          .fadeIn(
            begin: .3,
            duration: AppMotion.unitCardIn,
            curve: AppMotion.smoothOut,
          )
          .scaleXY(
            begin: AppMotion.scaleLarge,
            end: 1,
            duration: AppMotion.unitCardIn,
            curve: AppMotion.smoothOut,
          );
    }
    return card;
  }
}

class _FlatRow extends StatelessWidget {
  const _FlatRow({
    required this.lesson,
    required this.status,
    required this.book,
    required this.open,
    required this.onOpen,
  });

  final UnitLesson lesson;
  final UnitLessonStatus status;
  final bool book;
  final bool open;
  final VoidCallback onOpen;

  static const _minHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final locked = status == UnitLessonStatus.locked;
    final page = lesson.page;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: texts.bodyStrong.copyWith(
                        color: locked
                            ? colors.textSecondary
                            : colors.textPrimary,
                      ),
                    ),
                    _Meta(lesson: lesson, locked: locked),
                    if (book && page != null)
                      Text(
                        'unit_page'.tr(args: ['$page']),
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    if (lesson.isReview && locked)
                      Text(
                        'unit_review_after'.tr(),
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (status == UnitLessonStatus.done)
              Transform.translate(
                offset: const Offset(0, -AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconView(
                      AppIcon.check,
                      size: AppSizes.iconMd - 4,
                      color: colors.success.fill,
                    ),
                    TextButton(
                      onPressed: open ? onOpen : null,
                      child: Text('unit_redo'.tr()),
                    ),
                  ],
                ),
              )
            else if (status == UnitLessonStatus.open)
              Transform.translate(
                offset: const Offset(0, -AppSpacing.xs),
                child: IconButton(
                  tooltip: 'unit_start'.tr(),
                  onPressed: open ? onOpen : null,
                  color: colors.primary.text,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
