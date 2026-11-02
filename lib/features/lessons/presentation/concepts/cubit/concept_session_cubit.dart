import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/repositories/concept_repository.dart';
import 'package:englizia/features/lessons/domain/services/concept_stations.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A concept's card, its new question, what the answer did, and the session's end.
enum ConceptStage { card, question, result, done }

final class ConceptSessionState extends Equatable {
  const ConceptSessionState({
    this.concepts = const [],
    this.index = 0,
    this.stage = ConceptStage.card,
    this.draft,
    this.evaluation,
    this.outcome,
    this.outcomes = const [],
    this.audio = ClipStatus.idle,
    this.slow = false,
    this.clipLength = Duration.zero,
    this.playCount = 0,
  });

  final List<Concept> concepts;
  final int index;
  final ConceptStage stage;
  final ExerciseDraft? draft;
  final Evaluation? evaluation;
  final ConceptOutcome? outcome;

  /// What each answer did, for the end.
  final List<OutcomeKind> outcomes;
  final ClipStatus audio;
  final bool slow;
  final Duration clipLength;
  final int playCount;

  Concept? get concept => index < concepts.length ? concepts[index] : null;

  bool get canCheck => (draft?.isComplete ?? false) && evaluation == null;

  int count(OutcomeKind kind) => outcomes.where((o) => o == kind).length;

  ConceptSessionState copyWith({
    List<Concept>? concepts,
    int? index,
    ConceptStage? stage,
    ExerciseDraft? Function()? draft,
    Evaluation? Function()? evaluation,
    ConceptOutcome? Function()? outcome,
    List<OutcomeKind>? outcomes,
    ClipStatus? audio,
    bool? slow,
    Duration? clipLength,
    int? playCount,
  }) => ConceptSessionState(
    concepts: concepts ?? this.concepts,
    index: index ?? this.index,
    stage: stage ?? this.stage,
    draft: draft != null ? draft() : this.draft,
    evaluation: evaluation != null ? evaluation() : this.evaluation,
    outcome: outcome != null ? outcome() : this.outcome,
    outcomes: outcomes ?? this.outcomes,
    audio: audio ?? this.audio,
    slow: slow ?? this.slow,
    clipLength: clipLength ?? this.clipLength,
    playCount: playCount ?? this.playCount,
  );

  @override
  List<Object?> get props => [
    concepts,
    index,
    stage,
    draft,
    evaluation,
    outcome,
    outcomes,
    audio,
    slow,
    clipLength,
    playCount,
  ];
}

/// Strengthening concepts (requirements v3.0 §11.2): each concept's card, then a
/// new question in the lessons' own templates and feedback, then the station it
/// reached. It runs offline, as today's questions came with the concepts.
class ConceptSessionCubit extends Cubit<ConceptSessionState> {
  ConceptSessionCubit(this._concepts, ClipPlayer player)
    : _clip = ClipPlayback(player),
      super(const ConceptSessionState());

  static const slowSpeed = .75;

  final ConceptRepository _concepts;
  final ClipPlayback _clip;

  void start() => emit(
    ConceptSessionState(
      concepts: [
        for (final concept in _concepts.keptBank?.due ?? const <Concept>[])
          if (concept.question != null) concept,
      ],
    ),
  );

  /// «جرّب سؤالًا جديدًا».
  void tryQuestion() {
    if (state.concept == null) return;
    emit(state.copyWith(stage: ConceptStage.question));
  }

  void updateDraft(ExerciseDraft draft) {
    if (state.evaluation != null) return;
    emit(state.copyWith(draft: () => draft));
  }

  /// «تحقق».
  Future<void> check() async {
    final question = state.concept?.question;
    final draft = state.draft;
    if (question == null || draft == null || !state.canCheck) return;
    await stopAudio();
    emit(state.copyWith(evaluation: () => evaluate(question, draft)));
  }

  /// The feedback's «التالي»: the answer moves the concept.
  Future<void> answered() async {
    final concept = state.concept;
    final evaluation = state.evaluation;
    if (concept == null || evaluation == null) return;
    await stopAudio();
    final outcome = await _concepts.answer(
      concept,
      correct: evaluation.correct,
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        stage: ConceptStage.result,
        outcome: () => outcome,
        outcomes: [...state.outcomes, outcome.kind],
      ),
    );
  }

  /// «المفهوم التالي», or the end.
  void nextConcept() {
    final next = state.index + 1;
    emit(
      state.copyWith(
        index: next,
        stage: next >= state.concepts.length
            ? ConceptStage.done
            : ConceptStage.card,
        draft: () => null,
        evaluation: () => null,
        outcome: () => null,
        audio: ClipStatus.idle,
        playCount: 0,
      ),
    );
  }

  /// A question the learner can't answer now moves on, uncounted.
  void skip() => nextConcept();

  /// Another try, where the feedback offers it.
  void retry() =>
      emit(state.copyWith(draft: () => null, evaluation: () => null));

  Future<void> report(ProblemReason reason) async {
    final concept = state.concept;
    if (concept != null) await _concepts.report(concept, reason);
  }

  /// Concepts mastered in this session, for the list to see them leave.
  Set<String> get mastered => {
    for (final (i, kind) in state.outcomes.indexed)
      if (kind == OutcomeKind.mastered) state.concepts[i].id,
  };

  Future<void> togglePlay() async {
    if (state.audio == ClipStatus.playing) return stopAudio();
    if (state.audio != ClipStatus.loading) {
      await _play(state.concept?.question?.clipUrl, slow: false);
    }
  }

  Future<void> playSlow() async {
    if (state.audio == ClipStatus.loading) return;
    await stopAudio();
    await _play(state.concept?.question?.clipUrl, slow: true);
  }

  Future<void> toggleAnswerClip() async {
    if (state.audio == ClipStatus.playing) return stopAudio();
    if (state.audio != ClipStatus.loading) {
      await _play(state.concept?.question?.answerClipUrl, slow: false);
    }
  }

  Future<void> _play(String? url, {required bool slow}) async {
    if (url == null) return;
    emit(state.copyWith(audio: ClipStatus.loading, slow: slow));
    final outcome = await _clip.start(
      url,
      speed: slow ? slowSpeed : 1,
      onEnd: () {
        if (!isClosed) {
          emit(state.copyWith(audio: ClipStatus.idle, slow: false));
        }
      },
    );
    if (isClosed) return;
    switch (outcome) {
      case ClipCancelled():
        return;
      case ClipUnavailable():
        emit(state.copyWith(audio: ClipStatus.idle, slow: false));
      case ClipPlaying(:final length):
        emit(
          state.copyWith(
            audio: ClipStatus.playing,
            clipLength: length,
            playCount: state.playCount + 1,
          ),
        );
    }
  }

  Future<void> stopAudio() async {
    _clip.stop();
    if (state.audio == ClipStatus.playing ||
        state.audio == ClipStatus.loading) {
      emit(state.copyWith(audio: ClipStatus.idle, slow: false));
    }
  }

  @override
  Future<void> close() {
    _clip.stop();
    unawaited(_concepts.sendPending());
    return super.close();
  }
}
