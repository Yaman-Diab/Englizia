import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/fill_choices_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/image_choice_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/listen_choose_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/matching_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/multiple_choice_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/word_order_body.dart';
import 'package:flutter/widgets.dart';

/// Each template's question and answers. Exhaustive on purpose: a new template
/// doesn't compile until it has a body.
Widget exerciseBody(Exercise exercise, BodyAnswer answer, BodyClip clip) =>
    switch (exercise) {
      final MultipleChoiceExercise exercise => MultipleChoiceBody(
        exercise: exercise,
        answer: answer,
      ),
      final ImageChoiceExercise exercise => ImageChoiceBody(
        exercise: exercise,
        answer: answer,
        clip: clip,
      ),
      final ListenChooseExercise exercise => ListenChooseBody(
        exercise: exercise,
        answer: answer,
        clip: clip,
      ),
      final FillChoicesExercise exercise => FillChoicesBody(
        exercise: exercise,
        answer: answer,
      ),
      final WordOrderExercise exercise => WordOrderBody(
        exercise: exercise,
        answer: answer,
      ),
      final MatchingExercise exercise => MatchingBody(
        exercise: exercise,
        answer: answer,
      ),
    };
