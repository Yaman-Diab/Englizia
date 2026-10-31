import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/dialogue_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/error_correction_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/fill_choices_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/fill_typed_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/image_choice_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/listen_choose_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/listen_write_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/matching_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/multiple_choice_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/reading_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/repeat_sentence_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/sentence_order_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/speak_answer_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/spelling_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/translation_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/word_order_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/passage_card.dart';
import 'package:flutter/widgets.dart';

/// Each template's question and answers. Exhaustive on purpose: a new template
/// doesn't compile until it has a body.
Widget exerciseBody(
  Exercise exercise,
  BodyAnswer answer,
  BodyClip clip, {
  required VoidCallback onSkipSpeech,
}) => switch (exercise) {
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
  final RepeatSentenceExercise exercise => RepeatSentenceBody(
    exercise: exercise,
    answer: answer,
    clip: clip,
    onSkipSpeech: onSkipSpeech,
  ),
  final ListenWriteExercise exercise => ListenWriteBody(
    exercise: exercise,
    answer: answer,
    clip: clip,
  ),
  final FillTypedExercise exercise => FillTypedBody(
    exercise: exercise,
    answer: answer,
  ),
  final SentenceOrderExercise exercise => SentenceOrderBody(
    exercise: exercise,
    answer: answer,
  ),
  final SpellingExercise exercise => SpellingBody(
    exercise: exercise,
    answer: answer,
    clip: clip,
  ),
  final TranslationExercise exercise => TranslationBody(
    exercise: exercise,
    answer: answer,
  ),
  final ErrorCorrectionExercise exercise => ErrorCorrectionBody(
    exercise: exercise,
    answer: answer,
  ),
  final DialogueExercise exercise => DialogueBody(
    exercise: exercise,
    answer: answer,
  ),
  final ReadingExercise exercise => ReadingBody(
    exercise: exercise,
    answer: answer,
  ),
  final SpeakAnswerExercise exercise => SpeakAnswerBody(
    exercise: exercise,
    answer: answer,
    clip: clip,
    onSkipSpeech: onSkipSpeech,
  ),
};

/// What stays on screen while the question under it scrolls, and how tall it is.
({Widget child, double height})? exercisePinned(
  Exercise exercise,
  BodyClip clip, {
  required double screenHeight,
}) => switch (exercise) {
  final ReadingExercise exercise => (
    child: PassageCard(exercise: exercise, clip: clip),
    height: PassageCard.heightOn(screenHeight),
  ),
  _ => null,
};
