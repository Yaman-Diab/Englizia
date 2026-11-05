import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/pulse.dart';
import 'package:englizia/core/design_system/motion/shake.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/core/design_system/widgets/dashed_border.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/chip_stage.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/word_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A sentence with one blank or more, and the words for them. A tap sends a
/// word to the active blank, which then moves on to the next empty one; a tap
/// on a word in the sentence sends it back and makes its blank active, which
/// also covers replacing it. Which blank is active only draws this question, so
/// it stays here.
class FillChoicesBody extends StatefulWidget {
  const FillChoicesBody({
    required this.exercise,
    required this.answer,
    super.key,
  });

  final FillChoicesExercise exercise;
  final BodyAnswer answer;

  @override
  State<FillChoicesBody> createState() => _FillChoicesBodyState();
}

class _FillChoicesBodyState extends State<FillChoicesBody> {
  static const _lineHeight = 56.0;

  final _stage = GlobalKey<ChipStageState>();
  int? _active = 0;

  /// Counts each time a blank becomes active, for its one beat.
  var _beat = 0;

  List<WordChip?> get _slots => switch (widget.answer.draft) {
    SlotsDraft(:final chips) => chips,
    _ => List.filled(widget.exercise.blanks.length, null),
  };

  bool get _locked => widget.answer.evaluation != null;

  int? _nextEmpty(List<WordChip?> slots, int from) {
    for (var i = 1; i <= slots.length; i++) {
      final at = (from + i) % slots.length;
      if (slots[at] == null) return at;
    }
    return null;
  }

  void _choose(WordChip chip) {
    final active = _active;
    if (active == null) return;
    final slots = [..._slots];
    slots[active] = chip;
    final next = _nextEmpty(slots, active);
    AppHaptics.selectionClick();
    _stage.currentState!.move(
      [
        ChipMove(
          from: ChipStageState.bank(chip.id),
          to: ChipStageState.placed(chip.id),
          face: ChipFace(text: chip.text),
        ),
      ],
      () {
        setState(() {
          _active = next;
          _beat++;
        });
        widget.answer.onDraft(SlotsDraft(slots));
      },
    );
  }

  void _tapBlank(int index) {
    final chip = _slots[index];
    if (chip == null) {
      if (_active != index) {
        setState(() {
          _active = index;
          _beat++;
        });
      }
      return;
    }
    final slots = [..._slots];
    slots[index] = null;
    AppHaptics.selectionClick();
    _stage.currentState!.move(
      [
        ChipMove(
          from: ChipStageState.placed(chip.id),
          to: ChipStageState.bank(chip.id),
          face: ChipFace(text: chip.text),
        ),
      ],
      () {
        setState(() {
          _active = index;
          _beat++;
        });
        widget.answer.onDraft(SlotsDraft(slots));
      },
    );
  }

  ChoiceMark? _markOf(int index) => switch (widget.answer.evaluation) {
    SlotsEvaluation(:final slots) =>
      slots[index] ? ChoiceMark.correct : ChoiceMark.wrong,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final texts = context.texts;
    final reading = texts.reading;
    final slots = _slots;
    final used = {
      for (final chip in slots)
        if (chip != null) chip.id,
    };
    return ChipStage(
      key: _stage,
      builder: (context, stage) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text.rich(
              locale: const Locale('en'),
              TextSpan(
                // A blank is taller than a line of reading text.
                style: reading.copyWith(
                  color: context.colors.textPrimary,
                  height: _lineHeight / reading.fontSize!,
                ),
                children: [
                  for (final (i, segment) in exercise.segments.indexed) ...[
                    TextSpan(text: segment),
                    if (i < exercise.blanks.length)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: _blankAt(i, slots[i], stage),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          WordBank(
            stage: stage,
            chips: exercise.bank,
            used: used,
            onTap: _locked ? null : _choose,
            labelOf: (chip) =>
                'lesson_chip_add'.tr(namedArgs: {'word': chip.text}),
          ),
        ],
      ),
    );
  }

  Widget _blankAt(int index, WordChip? chip, ChipStageState stage) {
    final blank = _BlankBox(
      number: index + 1,
      word: chip == null || stage.isHidden(ChipStageState.placed(chip.id))
          ? null
          : chip.text,
      active: !_locked && chip == null && _active == index,
      beat: _active == index ? _beat : 0,
      mark: _markOf(index),
      onTap: _locked ? null : () => _tapBlank(index),
    );
    return chip == null
        ? blank
        : stage.slot(ChipStageState.placed(chip.id), blank, hideContent: false);
  }
}

/// A blank in the sentence: dashed and empty, dashed in the primary color and
/// thicker while active, or holding its word. Grows with a long word.
class _BlankBox extends StatelessWidget {
  const _BlankBox({
    required this.number,
    required this.word,
    required this.active,
    required this.beat,
    required this.mark,
    required this.onTap,
  });

  final int number;
  final String? word;
  final bool active;

  /// Changes each time this blank becomes active.
  final int beat;
  final ChoiceMark? mark;
  final VoidCallback? onTap;

  static const _minWidth = 88.0;
  static const _height = 44.0;
  static const _radius = AppRadius.md;
  static const _iconSize = 14.0;
  static const _ring = 8.0;
  static const _ringAlpha = .45;
  static const _pop = .03;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final word = this.word;
    final tone = switch (mark) {
      ChoiceMark.correct => colors.success,
      ChoiceMark.wrong => colors.error,
      null => null,
    };
    final radius = BorderRadius.circular(_radius);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _minWidth,
        minHeight: _height,
        maxHeight: _height,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (word != null)
              Text(
                word,
                style: texts.button.copyWith(color: colors.textPrimary),
              ),
            if (mark case final mark?) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                mark == ChoiceMark.correct
                    ? Icons.check_rounded
                    : Icons.close_rounded,
                size: _iconSize,
                color: tone?.fill,
              ),
            ],
          ],
        ),
      ),
    );
    final Widget box = word == null
        ? DashedBorder(
            color: active ? colors.primaryStrong : context.scheme.outline,
            radius: _radius,
            width: active ? 2 : 1.5,
            child: content,
          )
        : AnimatedContainer(
            duration: AppMotion.resolve(context, AppMotion.quick),
            decoration: BoxDecoration(
              color: tone?.surface ?? colors.surface,
              borderRadius: radius,
              border: Border.all(
                color: tone?.fill ?? context.scheme.outline,
                width: tone == null ? 1 : 2,
              ),
            ),
            child: content,
          );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm - AppSpacing.xxs,
      ),
      child: Semantics(
        button: true,
        label: word != null
            ? mark == null
                  ? 'lesson_chip_remove'.tr(namedArgs: {'word': word})
                  : mark == ChoiceMark.correct
                  ? 'lesson_chip_right'.tr(namedArgs: {'word': word})
                  : 'lesson_chip_wrong'.tr(namedArgs: {'word': word})
            : active
            ? 'lesson_blank_active'.tr(namedArgs: {'number': '$number'})
            : 'lesson_blank'.tr(namedArgs: {'number': '$number'}),
        child: ExcludeSemantics(
          child: Shake(
            trigger: mark == ChoiceMark.wrong,
            child: Pulse(
              trigger: mark == ChoiceMark.correct,
              growth: _pop,
              child: PressScale(
                enabled: onTap != null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: active && !AppMotion.reduceMotion(context)
                      ? Animate(
                          key: ValueKey(beat),
                          delay: AppMotion.characterPose,
                          effects: [
                            CustomEffect(
                              duration: AppMotion.verySlow,
                              curve: AppMotion.out,
                              builder: (_, value, child) => DecoratedBox(
                                position: DecorationPosition.foreground,
                                decoration: BoxDecoration(
                                  borderRadius: radius,
                                  border: value == 0
                                      ? null
                                      : Border.all(
                                          color: colors.primaryStrong
                                              .withValues(
                                                alpha: _ringAlpha * (1 - value),
                                              ),
                                          width: _ring * value,
                                          strokeAlign:
                                              BorderSide.strokeAlignOutside,
                                        ),
                                ),
                                child: child,
                              ),
                            ),
                          ],
                          child: box,
                        )
                      : box,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
