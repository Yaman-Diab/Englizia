import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/pulse.dart';
import 'package:englizia/core/design_system/motion/shake.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/chip_stage.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/word_chip.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/word_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One mistake in the sentence: tap it, then choose the correction, which flies
/// into its place. Right only with the right word and the right correction
/// together. Tapping another word moves the choice and drops the correction.
class ErrorCorrectionBody extends StatefulWidget {
  const ErrorCorrectionBody({
    required this.exercise,
    required this.answer,
    super.key,
  });

  final ErrorCorrectionExercise exercise;
  final BodyAnswer answer;

  @override
  State<ErrorCorrectionBody> createState() => _ErrorCorrectionBodyState();
}

class _ErrorCorrectionBodyState extends State<ErrorCorrectionBody> {
  final _stage = GlobalKey<ChipStageState>();

  CorrectionDraft? get _draft => switch (widget.answer.draft) {
    final CorrectionDraft draft => draft,
    _ => null,
  };

  bool get _locked => widget.answer.evaluation != null;

  void _pickWord(String tokenId) {
    HapticFeedback.selectionClick();
    final draft = _draft;
    widget.answer.onDraft(
      CorrectionDraft(
        tokenId: tokenId,
        replacement: draft?.tokenId == tokenId ? draft?.replacement : null,
      ),
    );
  }

  void _pickCorrection(WordChip chip) {
    final tokenId = _draft?.tokenId;
    if (tokenId == null) return;
    HapticFeedback.selectionClick();
    _stage.currentState!.move(
      [
        ChipMove(
          from: ChipStageState.bank(chip.id),
          to: ChipStageState.placed(tokenId),
          face: ChipFace(text: chip.text),
        ),
      ],
      () => widget.answer.onDraft(
        CorrectionDraft(tokenId: tokenId, replacement: chip.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final draft = _draft;
    final evaluation = widget.answer.evaluation;
    return ChipStage(
      key: _stage,
      builder: (context, stage) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              children: [
                for (final token in exercise.tokens)
                  stage.slot(
                    ChipStageState.placed(token.id),
                    _SentenceWord(
                      text: draft?.tokenId == token.id
                          ? draft?.replacement ?? token.text
                          : token.text,
                      replaced:
                          draft?.tokenId == token.id &&
                          draft?.replacement != null,
                      selected: draft?.tokenId == token.id,
                      mark: draft?.tokenId == token.id && evaluation != null
                          ? evaluation.correct
                                ? ChoiceMark.correct
                                : ChoiceMark.wrong
                          : null,
                      onTap: _locked ? null : () => _pickWord(token.id),
                    ),
                  ),
              ],
            ),
          ),
          if (draft != null && !_locked) ...[
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              motion: EntranceMotion.down,
              delay: Duration.zero,
              duration: AppMotion.closeUp,
              distance: AppMotion.distanceSmall,
              child: _CorrectionCard(
                stage: stage,
                chips: exercise.corrections,
                chosen: draft.replacement,
                onTap: _pickCorrection,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A word of the sentence to tap, with a dotted line that says it can be.
class _SentenceWord extends StatelessWidget {
  const _SentenceWord({
    required this.text,
    required this.replaced,
    required this.selected,
    required this.mark,
    required this.onTap,
  });

  final String text;
  final bool replaced;
  final bool selected;
  final ChoiceMark? mark;
  final VoidCallback? onTap;

  static const _pop = .03;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final tone = switch (mark) {
      ChoiceMark.correct => colors.success,
      ChoiceMark.wrong => colors.error,
      null => null,
    };
    final picked = selected || tone != null;
    final lineColor =
        tone?.fill ??
        (selected ? colors.primaryStrong : context.scheme.outline);
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? 'lesson_fix_selected'.tr(namedArgs: {'word': text})
          : 'lesson_fix_pick'.tr(namedArgs: {'word': text}),
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
                child: SizedBox(
                  height: AppSizes.minTapTarget,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: AnimatedContainer(
                        duration: AppMotion.resolve(context, AppMotion.quick),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.sm - AppSpacing.xxs,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color:
                              tone?.surface ??
                              (selected
                                  ? colors.primary.surface
                                  : Colors.transparent),
                          borderRadius: picked
                              ? BorderRadius.circular(AppRadius.sm)
                              : null,
                          border: picked
                              ? Border.all(color: lineColor, width: 1.5)
                              : null,
                        ),
                        child: CustomPaint(
                          foregroundPainter: picked
                              ? null
                              : WordLine(color: lineColor, dotted: true),
                          child: Text(
                            text,
                            locale: const Locale('en'),
                            style: texts.reading.copyWith(
                              fontFamily: replaced
                                  ? texts.bodyStrong.fontFamily
                                  : null,
                              color:
                                  tone?.text ??
                                  (replaced
                                      ? colors.primary.text
                                      : colors.textPrimary),
                            ),
                          ),
                        ),
                      ),
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

/// «اختر التصحيح»: opens under the sentence once a word is chosen.
class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({
    required this.stage,
    required this.chips,
    required this.chosen,
    required this.onTap,
  });

  final ChipStageState stage;
  final List<WordChip> chips;
  final String? chosen;
  final ValueChanged<WordChip> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'lesson_fix_choose'.tr(),
            style: context.texts.captionStrong.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final chip in chips)
                  stage.slot(
                    ChipStageState.bank(chip.id),
                    WordChipButton(
                      text: chip.text,
                      chosen: chosen == chip.text,
                      semanticLabel: chip.text,
                      onTap: () => onTap(chip),
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
}
