import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/dashed_border.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_card.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/chip_stage.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/lesson_picture.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/word_chip.dart';
import 'package:flutter/material.dart';

const _bubbleRadius = AppRadius.lg;
const _tightCorner = AppSpacing.xs;
const _replySlot = 'reply';

/// A conversation with a place for the learner's line, and the replies for it.
/// The character sits at the start and the learner at the end, as in the
/// conversation screen to come, without a messaging app's tails or colors. The
/// chosen reply flies to its bubble, which grows to fit.
class DialogueBody extends StatefulWidget {
  const DialogueBody({required this.exercise, required this.answer, super.key});

  final DialogueExercise exercise;
  final BodyAnswer answer;

  @override
  State<DialogueBody> createState() => _DialogueBodyState();
}

class _DialogueBodyState extends State<DialogueBody> {
  final _stage = GlobalKey<ChipStageState>();

  String? get _chosenText {
    if (widget.answer.draft case ChoiceDraft(:final optionId)) {
      for (final option in widget.exercise.options) {
        if (option.id == optionId) return option.text;
      }
    }
    return null;
  }

  void _choose(ExerciseOption option) {
    final tap = widget.answer.chooser(option.id);
    if (tap == null) return;
    _stage.currentState!.move([
      ChipMove(
        from: ChipStageState.bank(option.id),
        to: ChipStageState.placed(_replySlot),
        face: ChipFace(text: option.text),
      ),
    ], tap);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final answer = widget.answer;
    return ChipStage(
      key: _stage,
      builder: (context, stage) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: 'lesson_dialogue'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, line) in exercise.lines.indexed) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  Entrance(
                    motion: EntranceMotion.up,
                    delay: DialogueEntrance.line(i),
                    duration: AppMotion.fast,
                    distance: AppMotion.distanceBase,
                    child: line.isLearner
                        ? _LearnerBubble(stage: stage, text: _chosenText)
                        : _CharacterBubble(
                            name: exercise.characterName,
                            avatar: exercise.characterAvatar,
                            text: line.text,
                          ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final (i, option) in exercise.options.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            stage.slot(
              ChipStageState.bank(option.id),
              TextAnswer(
                text: option.text,
                look: answer.lookOf(option.id),
                onTap: answer.evaluation != null ? null : () => _choose(option),
              ),
              hideContent: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _CharacterBubble extends StatelessWidget {
  const _CharacterBubble({
    required this.name,
    required this.avatar,
    required this.text,
  });

  final String name;
  final String? avatar;
  final String text;

  static const _avatar = 32.0;
  static const _maxShare = .88;
  static const _nameHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avatar = this.avatar;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: _maxShare,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: _nameHeight),
              child: ExcludeSemantics(
                child: SizedBox.square(
                  dimension: _avatar,
                  child: avatar != null
                      ? ClipOval(child: LessonPicture(url: avatar))
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.info.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              name.characters.first,
                              style: context.texts.captionStrong.copyWith(
                                color: colors.info.text,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: context.texts.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadiusDirectional.only(
                        topStart: Radius.circular(_tightCorner),
                        topEnd: Radius.circular(_bubbleRadius),
                        bottomStart: Radius.circular(_bubbleRadius),
                        bottomEnd: Radius.circular(_bubbleRadius),
                      ),
                      border: Border.all(color: context.scheme.outline),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        text,
                        locale: const Locale('en'),
                        textDirection: TextDirection.ltr,
                        style: context.texts.body.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The learner's line: three dots in a dashed bubble, then the reply chosen.
class _LearnerBubble extends StatelessWidget {
  const _LearnerBubble({required this.stage, required this.text});

  final ChipStageState stage;
  final String? text;

  static const _minWidth = 72.0;
  static const _minHeight = 44.0;
  static const _maxShare = .8;
  static const _dot = 6.0;
  static const _dotStrengths = [1.0, .7, .45];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = this.text;
    const radius = BorderRadiusDirectional.only(
      topStart: Radius.circular(_bubbleRadius),
      topEnd: Radius.circular(_tightCorner),
      bottomStart: Radius.circular(_bubbleRadius),
      bottomEnd: Radius.circular(_bubbleRadius),
    );
    final body = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _minWidth,
        minHeight: _minHeight,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: text == null
            ? Semantics(
                container: true,
                label: 'lesson_dialogue_your_reply'.tr(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final (i, strength) in _dotStrengths.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.xs),
                      Container(
                        width: _dot,
                        height: _dot,
                        decoration: BoxDecoration(
                          color: colors.primaryStrong.withValues(
                            alpha: strength,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : Text(
                text,
                locale: const Locale('en'),
                textDirection: TextDirection.ltr,
                style: context.texts.body.copyWith(color: colors.textPrimary),
              ),
      ),
    );
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FractionallySizedBox(
        widthFactor: _maxShare,
        alignment: AlignmentDirectional.centerEnd,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AnimatedSize(
            duration: AppMotion.resolve(context, AppMotion.closeUp),
            curve: AppMotion.out,
            alignment: AlignmentDirectional.centerEnd,
            child: stage.slot(
              ChipStageState.placed(_replySlot),
              text == null
                  ? DashedBorder(
                      color: colors.primaryStrong,
                      radius: _bubbleRadius,
                      width: 1.5,
                      child: body,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary.surface,
                        borderRadius: radius,
                      ),
                      child: body,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
