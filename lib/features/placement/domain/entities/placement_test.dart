import 'package:equatable/equatable.dart';

/// A learner's run through the placement test (requirements v3.0 §12).
final class PlacementAttempt extends Equatable {
  const PlacementAttempt({
    required this.id,
    required this.stageSizes,
    required this.stage,
    required this.answered,
  });

  final String id;

  /// Questions of each stage known so far; a deciding stage joins when the
  /// server asks for it.
  final List<int> stageSizes;

  /// The stage to continue from, from 1.
  final int stage;

  /// Questions of [stage] the server already has.
  final int answered;

  @override
  List<Object?> get props => [id, stageSizes, stage, answered];
}

enum PlacementQuestionKind { vocabulary, grammar, reading, listening }

final class PlacementOption extends Equatable {
  const PlacementOption({required this.id, required this.text});

  final String id;
  final String text;

  @override
  List<Object?> get props => [id, text];
}

/// One question, with no answer key: those never reach the phone. The options
/// come shuffled for this learner.
final class PlacementQuestion extends Equatable {
  const PlacementQuestion({
    required this.id,
    required this.kind,
    required this.options,
    this.before = '',
    this.after = '',
    this.passage = '',
    this.ask = '',
    this.audioUrl = '',
    this.maxPlays = 0,
  });

  final String id;
  final PlacementQuestionKind kind;
  final List<PlacementOption> options;

  /// Vocabulary and grammar: the sentence around its blank.
  final String before;
  final String after;

  /// Reading: the text the question is about.
  final String passage;

  /// Reading and listening: what is asked.
  final String ask;

  /// Listening: the clip, and how many times it may be played.
  final String audioUrl;
  final int maxPlays;

  @override
  List<Object?> get props => [
    id,
    kind,
    options,
    before,
    after,
    passage,
    ask,
    audioUrl,
    maxPlays,
  ];
}

/// What comes after a stage.
final class PlacementNextStage extends Equatable {
  const PlacementNextStage({
    required this.stage,
    required this.questionCount,
    required this.listeningCount,
    required this.deciding,
  });

  final int stage;
  final int questionCount;
  final int listeningCount;

  /// The short stage that settles a result on the edge of two levels.
  final bool deciding;

  @override
  List<Object?> get props => [stage, questionCount, listeningCount, deciding];
}

/// An answer given; a null [optionId] is «لا أعرف».
final class PlacementAnswer extends Equatable {
  const PlacementAnswer({
    required this.attemptId,
    required this.stage,
    required this.questionId,
    required this.optionId,
    required this.plays,
  });

  final String attemptId;
  final int stage;
  final String questionId;
  final String? optionId;

  /// How often the question's clip was played.
  final int plays;

  @override
  List<Object?> get props => [attemptId, stage, questionId, optionId, plays];
}
