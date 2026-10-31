import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/pulse.dart';
import 'package:englizia/core/design_system/motion/shake.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/core/design_system/widgets/dashed_border.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/chip_stage.dart';
import 'package:flutter/material.dart';

const _wordLocale = Locale('en');
const _chipHeight = 48.0;
const _chipRadius = AppRadius.md;
const _pop = .03;

/// A word on its card, and nothing else: what flies between two places.
class ChipFace extends StatelessWidget {
  const ChipFace({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_chipRadius),
        border: Border.all(color: context.scheme.outline),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.sm,
            ),
            child: Text(
              text,
              locale: _wordLocale,
              maxLines: 1,
              style: context.texts.button.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// A word card to tap. After checking it carries the [mark], by color and icon
/// together, and stops answering.
class WordChipButton extends StatelessWidget {
  const WordChipButton({
    required this.text,
    required this.semanticLabel,
    required this.onTap,
    this.mark,
    this.chosen = false,
    super.key,
  });

  final String text;
  final String semanticLabel;
  final VoidCallback? onTap;
  final ChoiceMark? mark;

  /// One of a few to choose from, and this is the one.
  final bool chosen;

  static const _iconSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = switch (mark) {
      ChoiceMark.correct => colors.success,
      ChoiceMark.wrong => colors.error,
      null => null,
    };
    final radius = BorderRadius.circular(_chipRadius);
    return Shake(
      trigger: mark == ChoiceMark.wrong,
      child: Pulse(
        trigger: mark == ChoiceMark.correct,
        growth: _pop,
        child: PressScale(
          enabled: onTap != null,
          child: Semantics(
            button: true,
            selected: chosen,
            label: semanticLabel,
            child: ExcludeSemantics(
              child: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.quick),
                height: _chipHeight,
                decoration: BoxDecoration(
                  color:
                      tone?.surface ??
                      (chosen ? colors.primary.surface : colors.surface),
                  borderRadius: radius,
                  border: Border.all(
                    color:
                        tone?.fill ??
                        (chosen
                            ? colors.primaryStrong
                            : context.scheme.outline),
                    width: tone == null && !chosen ? 1 : 2,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: radius,
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            text,
                            locale: _wordLocale,
                            style: context.texts.button.copyWith(
                              color: colors.textPrimary,
                            ),
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

/// The words to build with, centered, left to right in any app language. A word
/// in use leaves its dashed shadow, so the rest don't move.
class WordBank extends StatelessWidget {
  const WordBank({
    required this.stage,
    required this.chips,
    required this.used,
    required this.onTap,
    required this.labelOf,
    super.key,
  });

  final ChipStageState stage;
  final List<WordChip> chips;

  /// Ids of the words in use.
  final Set<String> used;

  /// Null once the answer is locked.
  final ValueChanged<WordChip>? onTap;
  final String Function(WordChip chip) labelOf;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final chip in chips)
          stage.slot(
            ChipStageState.bank(chip.id),
            used.contains(chip.id) ||
                    stage.isHidden(ChipStageState.bank(chip.id))
                ? _ChipShadow(text: chip.text)
                : WordChipButton(
                    text: chip.text,
                    semanticLabel: labelOf(chip),
                    onTap: onTap == null ? null : () => onTap!(chip),
                  ),
            hideContent: false,
          ),
      ],
    ),
  );
}

/// Keeps a word's place: its size, with its text hidden, and hidden from screen
/// readers too.
class _ChipShadow extends StatelessWidget {
  const _ChipShadow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DashedBorder(
      color: context.scheme.outline,
      radius: _chipRadius,
      child: SizedBox(
        height: _chipHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
          ),
          child: Center(
            widthFactor: 1,
            child: Opacity(
              opacity: 0,
              child: Text(
                text,
                locale: _wordLocale,
                style: context.texts.button,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
