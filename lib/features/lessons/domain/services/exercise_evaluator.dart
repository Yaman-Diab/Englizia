import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';

/// Marks an answer on the phone, for instant feedback even offline (S §7.1).
Evaluation evaluate(Exercise exercise, ExerciseDraft draft) =>
    switch ((exercise, draft)) {
      (final ChoiceExercise exercise, final ChoiceDraft draft) =>
        ChoiceEvaluation(chosenId: draft.optionId, rightId: exercise.answerId),
    };
