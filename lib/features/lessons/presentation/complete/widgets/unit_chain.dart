import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/kind_icon.dart';
import 'package:flutter/material.dart';

/// The unit's lessons as a chain, from the start side: those done in green, the
/// next one ringed. The lesson just finished fills in, and the line reaches on.
class UnitChain extends StatelessWidget {
  const UnitChain({
    required this.unit,
    required this.lessonId,
    required this.moved,
    super.key,
  });

  final UnitProgress unit;
  final String lessonId;

  /// False on a lesson done again: the chain stays as it was (S §7.6).
  final bool moved;

  static const _node = 36.0;
  static const _line = 2.0;
  static const _iconSize = 18.0;

  double _share(int done) {
    final gaps = unit.steps.length - 1;
    return gaps <= 0 ? 0 : (done / gaps).clamp(0, 1);
  }

  String _described() {
    final next = unit.doneInARow;
    return [
      for (final (i, step) in unit.steps.indexed)
        step.done
            ? 'lesson_done_step_done'.tr(
                namedArgs: {'name': lessonKindName(step.kind)},
              )
            : i == next
            ? 'lesson_done_step_next'.tr(
                namedArgs: {'name': lessonKindName(step.kind)},
              )
            : lessonKindName(step.kind),
    ].join('lesson_done_step_join'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final done = unit.doneInARow;
    final just = moved
        ? unit.steps.indexWhere((step) => step.lessonId == lessonId)
        : -1;
    final from = _share(just < 0 ? done : done - 1);
    final to = _share(done);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'lesson_done_unit_title'.tr(
                  namedArgs: {'unit': '${unit.number}', 'title': unit.title},
                ),
                style: texts.bodyStrong.copyWith(color: colors.textPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'lesson_done_first_value'.tr(
                namedArgs: {'right': '$done', 'total': '${unit.steps.length}'},
              ),
              style: texts.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          image: true,
          label: _described(),
          excludeSemantics: true,
          child: SizedBox(
            height: _node,
            child: Stack(
              children: [
                PositionedDirectional(
                  start: _node / 2,
                  end: _node / 2,
                  top: (_node - _line) / 2,
                  height: _line,
                  child: ColoredBox(color: context.scheme.outline),
                ),
                PositionedDirectional(
                  start: _node / 2,
                  end: _node / 2,
                  top: (_node - _line) / 2,
                  height: _line,
                  child: TimedValue(
                    delay: LessonCompleteEntrance.chainLine,
                    duration: AppMotion.sheetIn,
                    builder: (_, value) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: from + (to - from) * value,
                        child: ColoredBox(color: colors.success.fill),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final (i, step) in unit.steps.indexed)
                      _Node(
                        icon: lessonKindIcon(step.kind),
                        state: step.done
                            ? _NodeState.done
                            : i == done
                            ? _NodeState.next
                            : _NodeState.todo,
                        just: i == just,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _NodeState { done, next, todo }

class _Node extends StatelessWidget {
  const _Node({required this.icon, required this.state, required this.just});

  final AppIcon icon;
  final _NodeState state;

  /// It was this lesson: its green pops in.
  final bool just;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.success.fill,
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: UnitChain._node),
    );
    return SizedBox.square(
      dimension: UnitChain._node,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: switch (state) {
                _NodeState.next => Border.all(
                  color: colors.primaryStrong,
                  width: 2,
                ),
                _NodeState.todo => Border.all(
                  color: context.scheme.outline,
                  width: 1.5,
                ),
                _NodeState.done => null,
              },
            ),
            child: const SizedBox.square(dimension: UnitChain._node),
          ),
          if (state == _NodeState.done)
            just
                ? TimedValue(
                    delay: LessonCompleteEntrance.chainNode,
                    duration: AppMotion.fast,
                    curve: AppMotion.overshoot,
                    builder: (_, value) =>
                        Transform.scale(scale: value, child: fill),
                  )
                : fill,
          AppIconView(
            icon,
            size: UnitChain._iconSize,
            color: switch (state) {
              _NodeState.done => colors.onPrimaryStrong,
              _NodeState.next => colors.primary.fill,
              _NodeState.todo => colors.textSecondary,
            },
          ),
        ],
      ),
    );
  }
}
