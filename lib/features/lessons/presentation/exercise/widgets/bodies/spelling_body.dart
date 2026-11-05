import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
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
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/lesson_picture.dart';
import 'package:flutter/material.dart';

/// The word's picture and sound, a place for each letter, and letters with two
/// extra among them. A tap sends a letter to the first empty place; a tap on a
/// placed one sends it back.
class SpellingBody extends StatefulWidget {
  const SpellingBody({
    required this.exercise,
    required this.answer,
    required this.clip,
    super.key,
  });

  final SpellingExercise exercise;
  final BodyAnswer answer;
  final BodyClip clip;

  @override
  State<SpellingBody> createState() => _SpellingBodyState();
}

class _SpellingBodyState extends State<SpellingBody> {
  static const _picture = 120.0;
  static const _circle = 40.0;
  static const _iconSize = 20.0;
  static const _ring = 4.0;

  final _stage = GlobalKey<ChipStageState>();

  List<WordChip?> get _slots => switch (widget.answer.draft) {
    SlotsDraft(:final chips) => chips,
    _ => List.filled(widget.exercise.word.length, null),
  };

  bool get _locked => widget.answer.evaluation != null;

  void _place(WordChip chip) {
    final slots = [..._slots];
    final at = slots.indexOf(null);
    if (at < 0) return;
    slots[at] = chip;
    AppHaptics.selectionClick();
    _stage.currentState!.move([
      ChipMove(
        from: ChipStageState.bank(chip.id),
        to: ChipStageState.placed(chip.id),
        face: _LetterFace(letter: chip.text),
      ),
    ], () => widget.answer.onDraft(SlotsDraft(slots)));
  }

  void _takeBack(int index, WordChip chip) {
    final slots = [..._slots];
    slots[index] = null;
    AppHaptics.selectionClick();
    _stage.currentState!.move([
      ChipMove(
        from: ChipStageState.placed(chip.id),
        to: ChipStageState.bank(chip.id),
        face: _LetterFace(letter: chip.text),
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
    final exercise = widget.exercise;
    final colors = context.colors;
    final clip = widget.clip;
    final slots = _slots;
    final firstEmpty = slots.indexOf(null);
    final used = {
      for (final chip in slots)
        if (chip != null) chip.id,
    };
    return ChipStage(
      key: _stage,
      builder: (context, stage) => Column(
        children: [
          Semantics(
            image: true,
            label: exercise.alt,
            child: SizedBox.square(
              dimension: _picture,
              child: LessonPicture(url: exercise.image),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          IconButton(
            onPressed: clip.onToggle,
            tooltip: 'lesson_listen_word'.tr(),
            style: IconButton.styleFrom(
              padding: EdgeInsetsDirectional.zero,
              fixedSize: const Size.square(AppSizes.minTapTarget),
            ),
            icon: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.quick),
              width: _circle,
              height: _circle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.info.fill,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: clip.status == ClipStatus.playing
                        ? colors.info.surface
                        : Colors.transparent,
                    spreadRadius: _ring,
                  ),
                ],
              ),
              child: AppIconView(
                AppIcon.volume,
                size: _iconSize,
                color: colors.surface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final (i, chip) in slots.indexed)
                  _slotAt(stage, i, chip, firstEmpty),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final chip in exercise.bank)
                  stage.slot(
                    ChipStageState.bank(chip.id),
                    _LetterKey(
                      letter: chip.text,
                      used:
                          used.contains(chip.id) ||
                          stage.isHidden(ChipStageState.bank(chip.id)),
                      onTap: _locked ? null : () => _place(chip),
                    ),
                    hideContent: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotAt(
    ChipStageState stage,
    int index,
    WordChip? chip,
    int firstEmpty,
  ) {
    final hidden =
        chip != null && stage.isHidden(ChipStageState.placed(chip.id));
    final slot = _LetterPlace(
      number: index + 1,
      letter: chip == null || hidden ? null : chip.text,
      active: !_locked && (index == firstEmpty || hidden),
      mark: _markOf(index),
      onTap: chip == null || _locked ? null : () => _takeBack(index, chip),
    );
    return chip == null
        ? slot
        : stage.slot(ChipStageState.placed(chip.id), slot, hideContent: false);
  }
}

/// A letter in the air.
class _LetterFace extends StatelessWidget {
  const _LetterFace({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.scheme.outline),
      ),
      child: Center(
        child: Text(
          letter,
          locale: const Locale('en'),
          style: context.texts.title.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }
}

/// A place for a letter, with a line under it, in the primary color when next.
class _LetterPlace extends StatelessWidget {
  const _LetterPlace({
    required this.number,
    required this.letter,
    required this.active,
    required this.mark,
    required this.onTap,
  });

  final int number;
  final String? letter;
  final bool active;
  final ChoiceMark? mark;
  final VoidCallback? onTap;

  static const _width = 44.0;
  static const _height = 52.0;
  static const _iconSize = 12.0;
  static const _iconInset = 3.0;
  static const _pop = .06;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final letter = this.letter;
    final tone = switch (mark) {
      ChoiceMark.correct => colors.success,
      ChoiceMark.wrong => colors.error,
      null => null,
    };
    return Semantics(
      button: letter != null,
      label: letter == null
          ? 'lesson_letter_empty'.tr(namedArgs: {'number': '$number'})
          : 'lesson_letter'.tr(
              namedArgs: {'number': '$number', 'letter': letter},
            ),
      child: ExcludeSemantics(
        child: Shake(
          trigger: mark == ChoiceMark.wrong,
          child: Pulse(
            trigger: mark == ChoiceMark.correct,
            growth: _pop,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.quick),
                width: _width,
                height: _height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      tone?.surface ??
                      (letter == null ? Colors.transparent : colors.surface),
                  borderRadius: const BorderRadiusDirectional.vertical(
                    top: Radius.circular(AppRadius.sm),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color:
                          tone?.fill ??
                          (active
                              ? colors.primaryStrong
                              : context.scheme.outline),
                      width: 2,
                    ),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (letter != null)
                      Text(
                        letter,
                        locale: const Locale('en'),
                        style: context.texts.title.copyWith(
                          color: tone?.text ?? colors.textPrimary,
                        ),
                      ),
                    if (mark case final mark?)
                      Positioned.directional(
                        textDirection: TextDirection.ltr,
                        top: _iconInset,
                        end: _iconInset,
                        child: Icon(
                          mark == ChoiceMark.correct
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          size: _iconSize,
                          color: tone?.fill,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A letter to tap; its dashed shadow keeps its place once in use.
class _LetterKey extends StatelessWidget {
  const _LetterKey({
    required this.letter,
    required this.used,
    required this.onTap,
  });

  final String letter;
  final bool used;
  final VoidCallback? onTap;

  static const _size = AppSizes.minTapTarget;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outline = context.scheme.outline;
    if (used) {
      return ExcludeSemantics(
        child: DashedBorder(
          color: outline,
          radius: AppRadius.md,
          child: const SizedBox.square(dimension: _size),
        ),
      );
    }
    return PressScale(
      enabled: onTap != null,
      child: Semantics(
        button: true,
        label: 'lesson_chip_add'.tr(namedArgs: {'word': letter}),
        child: ExcludeSemantics(
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                dimension: _size,
                child: Center(
                  child: Text(
                    letter,
                    locale: const Locale('en'),
                    style: context.texts.title.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
