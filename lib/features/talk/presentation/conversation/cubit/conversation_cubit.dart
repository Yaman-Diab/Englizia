import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/domain/repositories/talk_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum TalkStage { loading, failed, intro, chat }

enum TalkPhase {
  /// The character's voice plays.
  speaking,

  /// The learner's turn: speak, type or try a suggestion.
  turn,

  /// What the learner said, to send or say again.
  draft,

  /// The character thinks.
  thinking,

  /// «تعذّر الرد»: the turn didn't count, and can be sent again.
  failed,

  /// Every task is done, or the turns ran out.
  ended,
}

/// A bubble: the character's line, or what the learner said and how.
final class TalkMessage extends Equatable {
  const TalkMessage.character(this.line) : via = null;

  TalkMessage.mine(String text, SaidVia this.via)
    : line = TalkLine(english: text);

  final TalkLine line;
  final SaidVia? via;

  bool get mine => via != null;

  @override
  List<Object?> get props => [line, via];
}

final class ConversationState extends Equatable {
  const ConversationState({
    this.stage = TalkStage.loading,
    this.failure,
    this.scenario,
    this.starting = false,
    this.startFailure,
    this.messages = const [],
    this.phase = TalkPhase.speaking,
    this.draft = '',
    this.tasksDone = const {},
    this.turnsLeft = 0,
    this.suggestions = const [],
    this.translated = const {},
    this.speaking = false,
  });

  final TalkStage stage;
  final Failure? failure;
  final Scenario? scenario;

  /// «ابدأ المحادثة» waits for the server.
  final bool starting;

  /// Why the conversation couldn't start, shown once.
  final Failure? startFailure;
  final List<TalkMessage> messages;
  final TalkPhase phase;
  final String draft;
  final Set<String> tasksDone;
  final int turnsLeft;
  final List<TalkLine> suggestions;

  /// The character's bubbles shown with their Arabic, by index.
  final Set<int> translated;

  /// The character's voice plays, so its ring pulses.
  final bool speaking;

  bool get allDone =>
      scenario != null && tasksDone.length >= scenario!.tasks.length;

  ConversationState copyWith({
    TalkStage? stage,
    Failure? Function()? failure,
    Scenario? scenario,
    bool? starting,
    Failure? Function()? startFailure,
    List<TalkMessage>? messages,
    TalkPhase? phase,
    String? draft,
    Set<String>? tasksDone,
    int? turnsLeft,
    List<TalkLine>? suggestions,
    Set<int>? translated,
    bool? speaking,
  }) => ConversationState(
    stage: stage ?? this.stage,
    failure: failure != null ? failure() : this.failure,
    scenario: scenario ?? this.scenario,
    starting: starting ?? this.starting,
    startFailure: startFailure != null ? startFailure() : this.startFailure,
    messages: messages ?? this.messages,
    phase: phase ?? this.phase,
    draft: draft ?? this.draft,
    tasksDone: tasksDone ?? this.tasksDone,
    turnsLeft: turnsLeft ?? this.turnsLeft,
    suggestions: suggestions ?? this.suggestions,
    translated: translated ?? this.translated,
    speaking: speaking ?? this.speaking,
  );

  @override
  List<Object?> get props => [
    stage,
    failure,
    scenario,
    starting,
    startFailure,
    messages,
    phase,
    draft,
    tasksDone,
    turnsLeft,
    suggestions,
    translated,
    speaking,
  ];
}

/// A conversation with a character (requirements v3.0 §8.6, design "Talk"): its
/// intro, then turns until the tasks are done, the turns run out or the
/// learner ends it. Nothing is corrected on the way: the server keeps the notes
/// for the summary.
class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit(
    this._talk,
    ClipPlayer player, {
    required this.scenarioId,
    this.introDelay = const Duration(milliseconds: 400),
  }) : _playback = ClipPlayback(player),
       super(const ConversationState());

  final TalkRepository _talk;
  final ClipPlayback _playback;
  final String scenarioId;

  /// The intro plays by itself once the screen is up.
  final Duration introDelay;

  String? _conversationId;

  /// Lines the server has answered, which numbers the next turn.
  var _turn = 0;
  Timer? _introTimer;

  /// What happens when the line playing ends, or is cut short.
  void Function()? _afterLine;

  Future<void> start() async {
    emit(state.copyWith(stage: TalkStage.loading, failure: () => null));
    final result = await _talk.getScenario(scenarioId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            stage: TalkStage.intro,
            scenario: value,
            turnsLeft: value.maxTurns,
            suggestions: value.suggestions,
          ),
        );
        _introTimer = Timer(introDelay, playIntro);
      case Err(:final failure):
        emit(state.copyWith(stage: TalkStage.failed, failure: () => failure));
    }
  }

  void playIntro() {
    if (state.stage != TalkStage.intro) return;
    unawaited(_play(state.scenario!.intro.audioUrl));
  }

  /// «ابدأ المحادثة»: counts against today's AI conversations, then the
  /// character opens with its fixed line.
  Future<void> begin() async {
    if (state.starting || state.stage != TalkStage.intro) return;
    _introTimer?.cancel();
    _stopLine();
    emit(state.copyWith(starting: true, startFailure: () => null));
    final result = await _talk.start(scenarioId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _conversationId = value;
        final opening = state.scenario!.opening;
        emit(
          state.copyWith(
            stage: TalkStage.chat,
            starting: false,
            messages: [TalkMessage.character(opening)],
            phase: TalkPhase.speaking,
          ),
        );
        await _speak(opening);
      case Err(:final failure):
        emit(state.copyWith(starting: false, startFailure: () => failure));
    }
  }

  /// What the microphone understood, to read before sending.
  void heard(String text) {
    if (state.phase != TalkPhase.turn || text.trim().isEmpty) return;
    emit(state.copyWith(phase: TalkPhase.draft, draft: text.trim()));
  }

  /// «أعد»: the draft goes, and the learner speaks again.
  void redo() {
    if (state.phase != TalkPhase.draft) return;
    emit(state.copyWith(phase: TalkPhase.turn, draft: ''));
  }

  Future<void> sendDraft() async {
    if (state.phase != TalkPhase.draft) return;
    await _send(state.draft, SaidVia.mic);
  }

  /// Sends what the learner typed; false when it isn't their turn.
  bool sendTyped(String text) {
    if (state.phase != TalkPhase.turn || text.trim().isEmpty) return false;
    unawaited(_send(text.trim(), SaidVia.keyboard));
    return true;
  }

  Future<void> _send(String text, SaidVia via) async {
    emit(
      state.copyWith(
        messages: [...state.messages, TalkMessage.mine(text, via)],
        phase: TalkPhase.thinking,
        draft: '',
      ),
    );
    await _ask();
  }

  /// «إعادة المحاولة»: the same line again, with the same turn.
  Future<void> retry() async {
    if (state.phase != TalkPhase.failed) return;
    emit(state.copyWith(phase: TalkPhase.thinking));
    await _ask();
  }

  Future<void> _ask() async {
    final mine = state.messages.lastWhere((message) => message.mine);
    final result = await _talk.say(
      _conversationId!,
      turn: _turn,
      text: mine.line.english,
      via: mine.via!,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _turn++;
        emit(
          state.copyWith(
            messages: [...state.messages, TalkMessage.character(value.line)],
            tasksDone: value.tasksDone,
            turnsLeft: value.turnsLeft,
            suggestions: value.suggestions,
            phase: TalkPhase.speaking,
          ),
        );
        await _speak(value.line);
      case Err():
        emit(state.copyWith(phase: TalkPhase.failed));
    }
  }

  void toggleTranslation(int index) {
    final translated = {...state.translated};
    if (!translated.remove(index)) translated.add(index);
    emit(state.copyWith(translated: translated));
  }

  /// A character's line again, cutting short whatever plays.
  Future<void> replay(int index) =>
      _play(state.messages[index].line.audioUrl, character: true);

  /// «جرّب أن تقول»: only heard; the learner says it themselves.
  Future<void> playSuggestion(TalkLine line) => _play(line.audioUrl);

  /// «أنهِ الآن», or on to the summary once it has ended.
  void end() {
    _introTimer?.cancel();
    _stopLine();
    if (_conversationId case final id?) unawaited(_talk.end(id));
  }

  Future<void> _speak(TalkLine line) =>
      _play(line.audioUrl, character: true, after: _afterCharacter);

  void _afterCharacter() {
    if (isClosed || state.phase != TalkPhase.speaking) return;
    final over = state.allDone || state.turnsLeft <= 0;
    emit(state.copyWith(phase: over ? TalkPhase.ended : TalkPhase.turn));
  }

  /// One line at a time: a new one cuts the last short, and what was to follow
  /// that one happens at once. A voice that fails leaves the text alone.
  Future<void> _play(
    String? url, {
    bool character = false,
    void Function()? after,
  }) async {
    _stopLine();
    _afterLine = after;
    if (url == null) return _stopLine();
    if (character) emit(state.copyWith(speaking: true));
    final outcome = await _playback.start(url, onEnd: _stopLine);
    if (outcome is ClipUnavailable) _stopLine();
  }

  void _stopLine() {
    _playback.stop();
    if (!isClosed && state.speaking) emit(state.copyWith(speaking: false));
    final after = _afterLine;
    _afterLine = null;
    after?.call();
  }

  @override
  Future<void> close() {
    _introTimer?.cancel();
    _afterLine = null;
    _playback.stop();
    return super.close();
  }
}
