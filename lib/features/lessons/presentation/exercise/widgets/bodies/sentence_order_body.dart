import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/pulse.dart';
import 'package:englizia/core/design_system/motion/shake.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/core/design_system/widgets/dashed_border.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/chip_stage.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/word_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _rowHeight = 56.0;

/// Numbered places for sentences, and the sentences under them. A tap sends one
/// to the first empty place, whose number says so; a tap on a placed one sends
/// it back.
class SentenceOrderBody extends StatefulWidget {
  const SentenceOrderBody({
    required this.exercise,
    required this.answer,
    super.key,
  });

  final SentenceOrderExercise exercise;
  final BodyAnswer answer;

  @override
  State<SentenceOrderBody> createState() => _SentenceOrderBodyState();
}

class _SentenceOrderBodyState extends State<SentenceOrderBody> {
  final _stage = GlobalKey<ChipStageState>();

  List<WordChip?> get _slots => switch (widget.answer.draft) {
    SlotsDraft(:final chips) => chips,
    _ => List.filled(widget.exercise.sentences.length, null),
  };

  bool get _locked => widget.answer.evaluation != null;

  void _place(WordChip chip) {
    final slots = [..._slots];
    final at = slots.indexOf(null);
    if (at < 0) return;
    slots[at] = chip;
    HapticFeedback.selectionClick();
    _stage.currentState!.move([
      ChipMove(
        from: ChipStageState.bank(chip.id),
        to: ChipStageState.placed(chip.id),
        face: ChipFace(text: chip.text),
      ),
    ], () => widget.answer.onDraft(SlotsDraft(slots)));
  }

  void _takeBack(int index, WordChip chip) {
    final slots = [..._slots];
    slots[index] = null;
    HapticFeedback.selectionClick();
    _stage.currentState!.move([
      ChipMove(
        from: ChipStageState.placed(chip.id),
        to: ChipStageState.bank(chip.id),
        face: ChipFace(text: chip.text),
      ),
    ], () => widget.answer.onDraft(SlotsDraft(slots)));
  }

  ChoiceMark? _markOf(int index) => switch (widget.answer.evaluation) {
    SlotsEvaluation(:final slots) =>
      slots[index] ? ChoiceMark.correct : ChoiceMark.wrong,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    final firstEmpty = slots.indexOf(null);
    final used = {
      for (final chip in slots)
        if (chip != null) chip.id,
    };
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ChipStage(
        key: _stage,
        builder: (context, stage) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, chip) in slots.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _placeAt(stage, i, chip, firstEmpty),
            ],
            const SizedBox(height: AppSpacing.xl),
            for (final (i, chip) in widget.exercise.bank.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              stage.slot(
                ChipStageState.bank(chip.id),
                _BankRow(
                  text: chip.text,
                  used:
                      used.contains(chip.id) ||
                      stage.isHidden(ChipStageState.bank(chip.id)),
                  onTap: _locked ? null : () => _place(chip),
                ),
                hideContent: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeAt(
    ChipStageState stage,
    int index,
    WordChip? chip,
    int firstEmpty,
  ) {
    final hidden =
        chip != null && stage.isHidden(ChipStageState.placed(chip.id));
    final row = _PlaceRow(
      number: index + 1,
      text: chip == null || hidden ? null : chip.text,
      active: !_locked && (index == firstEmpty || hidden),
      mark: _markOf(index),
      onTap: chip == null || _locked ? null : () => _takeBack(index, chip),
    );
    return chip == null
        ? row
        : stage.slot(ChipStageState.placed(chip.id), row, hideContent: false);
  }
}

/// A numbered place: dashed while empty, in the primary color when next.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.number,
    required this.text,
    required this.active,
    required this.mark,
    required this.onTap,
  });

  final int number;
  final String? text;
  final bool active;
  final ChoiceMark? mark;
  final VoidCallback? onTap;

  static const _circle = 28.0;
  static const _iconSize = 14.0;
  static const _pop = .02;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final text = this.text;
    final tone = switch (mark) {
      ChoiceMark.correct => colors.success,
      ChoiceMark.wrong => colors.error,
      null => null,
    };
    final filled = text != null;
    final outline = context.scheme.outline;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.quick),
              width: _circle,
              height: _circle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    tone?.fill ??
                    (filled ? colors.primary.surface : Colors.transparent),
                border: filled
                    ? null
                    : Border.all(
                        color: active ? colors.primaryStrong : outline,
                        width: 1.5,
                      ),
              ),
              child: Text(
                '$number',
                style: texts.captionStrong.copyWith(
                  color: tone != null
                      ? colors.surface
                      : filled || active
                      ? colors.primary.text
                      : colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: filled
                  ? Text(
                      text,
                      locale: const Locale('en'),
                      style: texts.body.copyWith(color: colors.textPrimary),
                    )
                  : const SizedBox.shrink(),
            ),
            if (mark case final mark?) ...[
              const SizedBox(width: AppSpacing.sm),
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
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: filled,
      label: filled
          ? mark == null
                ? 'lesson_place_remove'.tr(
                    namedArgs: {'number': '$number', 'text': text},
                  )
                : mark == ChoiceMark.correct
                ? 'lesson_chip_right'.tr(namedArgs: {'word': text})
                : 'lesson_chip_wrong'.tr(namedArgs: {'word': text})
          : 'lesson_place_empty'.tr(namedArgs: {'number': '$number'}),
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
                child: filled
                    ? AnimatedContainer(
                        duration: AppMotion.resolve(context, AppMotion.quick),
                        decoration: BoxDecoration(
                          color: tone?.surface ?? colors.surface,
                          borderRadius: radius,
                          border: Border.all(
                            color: tone?.fill ?? outline,
                            width: tone == null ? 1 : 2,
                          ),
                        ),
                        child: row,
                      )
                    : DashedBorder(
                        color: active ? colors.primaryStrong : outline,
                        radius: AppRadius.md,
                        width: 1.5,
                        child: row,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sentence to place; its shadow keeps its size once in use.
class _BankRow extends StatelessWidget {
  const _BankRow({required this.text, required this.used, required this.onTap});

  final String text;
  final bool used;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outline = context.scheme.outline;
    final radius = BorderRadius.circular(AppRadius.md);
    final body = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: _rowHeight,
        minWidth: double.infinity,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Opacity(
            opacity: used ? 0 : 1,
            child: Text(
              text,
              locale: const Locale('en'),
              style: context.texts.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
    if (used) {
      return ExcludeSemantics(
        child: DashedBorder(color: outline, radius: AppRadius.md, child: body),
      );
    }
    return PressScale(
      enabled: onTap != null,
      child: Semantics(
        button: true,
        label: 'lesson_chip_add'.tr(namedArgs: {'word': text}),
        child: ExcludeSemantics(
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, child: body),
          ),
        ),
      ),
    );
  }
}
