import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/widgets/blank_sentence.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_card.dart';
import 'package:flutter/widgets.dart';

/// A sentence with its blank: the word chosen shows inside it before checking.
class MultipleChoiceBody extends StatelessWidget {
  const MultipleChoiceBody({
    required this.exercise,
    required this.answer,
    super.key,
  });

  final MultipleChoiceExercise exercise;
  final BodyAnswer answer;

  String? get _word {
    if (answer.draft case ChoiceDraft(:final optionId)) {
      for (final option in exercise.options) {
        if (option.id == optionId) return option.text;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BlankSentence(
        before: exercise.before,
        after: exercise.after,
        word: _word,
      ),
      const SizedBox(height: AppSpacing.xl),
      TextAnswers(options: exercise.options, answer: answer),
    ],
  );
}
