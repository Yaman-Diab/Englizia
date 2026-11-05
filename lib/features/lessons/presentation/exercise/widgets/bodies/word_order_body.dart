import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/core/design_system/widgets/speech_bubble.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/chip_stage.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/word_chip.dart';
import 'package:flutter/material.dart';

/// The guide says the meaning in Arabic, and the learner builds the English on
/// its lines, left to right in any app language. A tap sends a word up or back;
/// what follows a word taken out closes up.
class WordOrderBody extends StatefulWidget {
  const WordOrderBody({
    required this.exercise,
    required this.answer,
    super.key,
  });

  final WordOrderExercise exercise;
  final BodyAnswer answer;

  @override
  State<WordOrderBody> createState() => _WordOrderBodyState();
}

class _WordOrderBodyState extends State<WordOrderBody> {
  static const _guide = 56.0;

  final _stage = GlobalKey<ChipStageState>();

  List<WordChip> get _placed => switch (widget.answer.draft) {
    SequenceDraft(:final chips) => chips,
    _ => const [],
  };

  bool get _locked => widget.answer.evaluation != null;

  void _send(List<WordChip> placed, ChipMove move) {
    AppHaptics.selectionClick();
    _stage.currentState!.move([
      move,
    ], () => widget.answer.onDraft(SequenceDraft(placed, needed: _needed)));
  }

  int get _needed => widget.exercise.answerWords.length;

  void _add(WordChip chip) => _send(
    [..._placed, chip],
    ChipMove(
      from: ChipStageState.bank(chip.id),
      to: ChipStageState.placed(chip.id),
      face: ChipFace(text: chip.text),
    ),
  );

  void _remove(WordChip chip) => _send(
    [
      for (final placed in _placed)
        if (placed.id != chip.id) placed,
    ],
    ChipMove(
      from: ChipStageState.placed(chip.id),
      to: ChipStageState.bank(chip.id),
      face: ChipFace(text: chip.text),
    ),
  );

  ChoiceMark? _markOf(int index) => switch (widget.answer.evaluation) {
    SequenceEvaluation(:final words) =>
      words[index] ? ChoiceMark.correct : ChoiceMark.wrong,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final placed = _placed;
    return ChipStage(
      key: _stage,
      builder: (context, stage) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox.square(
                dimension: _guide,
                child: Mascot(
                  expression: MascotExpression.talk,
                  size: _guide,
                  animate: false,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SpeechBubble(
                  text: widget.exercise.meaning,
                  strong: false,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _BuildingLines(
            semanticLabel: 'lesson_your_sentence'.tr(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (i, chip) in placed.indexed)
                    stage.slot(
                      ChipStageState.placed(chip.id),
                      WordChipButton(
                        text: chip.text,
                        mark: _markOf(i),
                        semanticLabel: switch (_markOf(i)) {
                          null => 'lesson_chip_remove'.tr(
                            namedArgs: {'word': chip.text},
                          ),
                          ChoiceMark.correct => 'lesson_chip_right'.tr(
                            namedArgs: {'word': chip.text},
                          ),
                          ChoiceMark.wrong => 'lesson_chip_wrong'.tr(
                            namedArgs: {'word': chip.text},
                          ),
                        },
                        onTap: _locked ? null : () => _remove(chip),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          WordBank(
            stage: stage,
            chips: widget.exercise.bank,
            used: {for (final chip in placed) chip.id},
            onTap: _locked ? null : _add,
            labelOf: (chip) =>
                'lesson_chip_add'.tr(namedArgs: {'word': chip.text}),
          ),
        ],
      ),
    );
  }
}

/// The writing lines under the words: two at least, and more if the sentence
/// runs longer.
class _BuildingLines extends StatelessWidget {
  const _BuildingLines({required this.semanticLabel, required this.child});

  final String semanticLabel;
  final Widget child;

  static const _minHeight = 112.0;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: CustomPaint(
      painter: _LinesPainter(context.scheme.outline),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: _minHeight,
          minWidth: double.infinity,
        ),
        child: child,
      ),
    ),
  );
}

class _LinesPainter extends CustomPainter {
  const _LinesPainter(this.color);

  final Color color;

  /// Under a row of words: a word's height, and half the gap between rows.
  static const _firstLine = 52.0;
  static const _rowHeight = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = _firstLine; y <= size.height; y += _rowHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_LinesPainter oldDelegate) => oldDelegate.color != color;
}
