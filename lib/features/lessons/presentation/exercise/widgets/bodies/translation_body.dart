import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/speech_bubble.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_text_field.dart';
import 'package:flutter/material.dart';

/// The guide says an Arabic sentence, and the learner writes it in English,
/// against the saved translations, as there is more than one right way.
class TranslationBody extends StatefulWidget {
  const TranslationBody({
    required this.exercise,
    required this.answer,
    super.key,
  });

  final TranslationExercise exercise;
  final BodyAnswer answer;

  @override
  State<TranslationBody> createState() => _TranslationBodyState();
}

class _TranslationBodyState extends State<TranslationBody> {
  static const _guide = 56.0;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void didUpdateWidget(TranslationBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.answer.evaluation != null) _focus.unfocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
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
              text: widget.exercise.arabic,
              textDirection: TextDirection.rtl,
              style: context.texts.reading.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      AnswerTextField(
        controller: _controller,
        focusNode: _focus,
        correct: widget.answer.evaluation?.correct,
        onChanged: (text) => widget.answer.onDraft(TextDraft(text)),
      ),
    ],
  );
}
