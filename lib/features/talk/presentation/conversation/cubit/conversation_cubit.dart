import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/text/plain_words.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/domain/repositories/talk_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum TalkStage { loading, failed, intro, chat, summary }

enum TalkPhase {
  /// The character's voice plays.
  speaking,

  /// The learner's turn: speak, type, try a suggestion, or in a written
  /// conversation repeat the sentence or choose a reply.
  turn,

  /// What the learner said, to send or say again.
  draft,

  /// «ردّد»: the words heard show for a moment, then the sentence goes.
  heard,

  /// A written conversation's line is sent, and the character answers next.
  sent,

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
    this.turn = 0,
    this.heard,
    this.notes,
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

  /// The learner's lines answered so far, which is also a written
  /// conversation's turn.
  final int turn;

  /// «ردّد»: which of the sentence's words were heard.
  final List<bool>? heard;

  /// An AI conversation's notes for the summary; null when there are none to
  /// wait for.
  final TalkNotes? notes;

  bool get written => scenario?.kind == TalkKind.written;

  bool get allDone =>
      scenario != null && tasksDone.length >= scenario!.tasks.length;

  /// A written conversation's turn now, while there is one.
  ScriptTurn? get scriptTurn {
    final script = scenario?.script ?? const [];
    return written && turn < script.length ? script[turn] : null;
  }

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
    int? turn,
    List<bool>? Function()? heard,
    TalkNotes? Function()? notes,
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
    turn: turn ?? this.turn,
    heard: heard != null ? heard() : this.heard,
    notes: notes != null ? notes() : this.notes,
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
    turn,
    heard,
    notes,
  ];
}

/// A conversation with a character (requirements v3.0 §8.6, designs "Talk" and
/// "Talk Summary"): its intro, then turns until the tasks are done, the turns
/// run out or the learner ends it, then its summary. An AI conversation asks
/// the server for each answer; a written one follows its script on the phone.
/// Nothing is corrected on the way: the server keeps the notes for the summary.
class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit(
    this._talk,
    ClipPlayer player, {
    required this.scenarioId,
    this.introDelay = const Duration(milliseconds: 400),
    this.heardHold = const Duration(milliseconds: 1600),
    this.replyDelay = const Duration(milliseconds: 700),
    this.notesRetry = const Duration(seconds: 3),
    this.notesTries = 5,
  }) : _playback = ClipPlayback(player),
       super(const ConversationState());

  final TalkRepository _talk;
  final ClipPlayback _playback;
  final String scenarioId;

  /// The intro plays by itself once the screen is up.
  final Duration introDelay;

  /// ASSUMPTION(design): how long «ردّد»'s words heard stay before the
  /// sentence goes, and the wait before a written conversation's answer.
  final Duration heardHold;
  final Duration replyDelay;

  /// While the notes are being made, they are asked for again this often, up
  /// to [notesTries] times; then they come «later».
  final Duration notesRetry;
  final int notesTries;

  String? _conversationId;
  Timer? _introTimer;
  Timer? _scriptTimer;
  Timer? _notesTimer;

  /// What happens when the line playing ends, or is cut short.
  void Function()? _afterLine;

  Future<void> start() async {
    emit(state.copyWith(stage: TalkStage.loading, failure: () => null));
    final result = await _talk.getScenario(scenarioId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(stage: TalkStage.intro, scenario: value));
        _introTimer = Timer(introDelay, playIntro);
      case Err(:final failure):
        emit(state.copyWith(stage: TalkStage.failed, failure: () => failure));
    }
  }

  void playIntro() {
    if (state.stage != TalkStage.intro) return;
    unawaited(_play(state.scenario!.intro.audioUrl));
  }

  /// «ابدأ المحادثة»: an AI conversation counts against today's, then the
  /// character opens with its fixed line.
  Future<void> begin() async {
    if (state.starting) return;
    _introTimer?.cancel();
    _stopLine();
    emit(state.copyWith(starting: true, startFailure: () => null));
    final result = await _talk.start(scenarioId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _conversationId = value;
        final scenario = state.scenario!;
        emit(
          ConversationState(
            stage: TalkStage.chat,
            scenario: scenario,
            messages: [TalkMessage.character(scenario.opening)],
            turnsLeft: scenario.kind == TalkKind.written
                ? scenario.script.length
                : scenario.maxTurns,
            suggestions: scenario.suggestions,
          ),
        );
        await _speak(scenario.opening);
      case Err(:final failure):
        emit(state.copyWith(starting: false, startFailure: () => failure));
    }
  }

  /// What the microphone understood: a draft to read before sending, or in a
  /// written conversation the sentence's words heard.
  void heard(String text) {
    if (state.phase != TalkPhase.turn || text.trim().isEmpty) return;
    if (state.scriptTurn case RepeatTurn(
      :final sentence,
      :final reply,
      :final taskId,
    )) {
      emit(
        state.copyWith(
          phase: TalkPhase.heard,
          heard: () => heardWords(sentence.english.split(' '), text),
        ),
      );
      _scriptTimer = Timer(
        heardHold,
        () => _sendScripted(sentence.english, SaidVia.mic, reply, taskId),
      );
      return;
    }
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
    if (state.phase != TalkPhase.turn || text.trim().isEmpty || state.written) {
      return false;
    }
    unawaited(_send(text.trim(), SaidVia.keyboard));
    return true;
  }

  /// «اختر ردك»: the reply goes, and the character answers it its way.
  void choose(int index) {
    if (state.phase != TalkPhase.turn) return;
    if (state.scriptTurn case ChooseTurn(:final options)) {
      final option = options[index];
      _sendScripted(
        option.said.english,
        SaidVia.choice,
        option.reply,
        option.taskId,
      );
    }
  }

  void _sendScripted(String text, SaidVia via, TalkLine reply, String? taskId) {
    if (isClosed) return;
    emit(
      state.copyWith(
        messages: [...state.messages, TalkMessage.mine(text, via)],
        phase: TalkPhase.sent,
        heard: () => null,
      ),
    );
    _scriptTimer = Timer(replyDelay, () {
      if (isClosed) return;
      final turn = state.turn + 1;
      emit(
        state.copyWith(
          messages: [...state.messages, TalkMessage.character(reply)],
          tasksDone: {...state.tasksDone, ?taskId},
          turn: turn,
          turnsLeft: state.scenario!.script.length - turn,
          phase: TalkPhase.speaking,
        ),
      );
      unawaited(_speak(reply));
    });
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
      turn: state.turn,
      text: mine.line.english,
      via: mine.via!,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            messages: [...state.messages, TalkMessage.character(value.line)],
            tasksDone: value.tasksDone,
            turnsLeft: value.turnsLeft,
            suggestions: value.suggestions,
            turn: state.turn + 1,
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

  /// A suggestion, a written reply or a sentence to repeat: only heard.
  Future<void> playLine(TalkLine line) => _play(line.audioUrl);

  /// The better way to say a line.
  Future<void> playBetter(BetterSaying better) => _play(better.audioUrl);

  /// «أنهِ الآن», or «الملخص» once it has ended: the tasks done go to the
  /// server, and an AI conversation's notes are asked for.
  void finish() {
    _introTimer?.cancel();
    _scriptTimer?.cancel();
    _stopLine();
    if (_conversationId case final id?) {
      unawaited(_talk.end(id, tasksDone: state.tasksDone));
    }
    final waitForNotes =
        !state.written && state.messages.any((message) => message.mine);
    emit(
      state.copyWith(
        stage: TalkStage.summary,
        notes: () =>
            waitForNotes ? const TalkNotes(status: NotesStatus.pending) : null,
      ),
    );
    if (waitForNotes) unawaited(_loadNotes(1));
  }

  Future<void> _loadNotes(int attempt) async {
    final result = await _talk.notes(_conversationId!);
    if (isClosed || state.stage != TalkStage.summary) return;
    switch (result) {
      case Ok(value: TalkNotes(status: NotesStatus.pending)):
        if (attempt < notesTries) {
          _notesTimer = Timer(notesRetry, () => _loadNotes(attempt + 1));
        } else {
          emit(
            state.copyWith(
              notes: () => const TalkNotes(status: NotesStatus.failed),
            ),
          );
        }
      case Ok(:final value):
        emit(state.copyWith(notes: () => value));
      case Err():
        emit(
          state.copyWith(
            notes: () => const TalkNotes(status: NotesStatus.failed),
          ),
        );
    }
  }

  /// «أعد المحاولة»: an AI conversation goes back to its intro, as it counts
  /// against the day's; a written one starts again at once.
  Future<void> restart() async {
    _notesTimer?.cancel();
    _stopLine();
    _conversationId = null;
    final scenario = state.scenario!;
    emit(ConversationState(stage: TalkStage.intro, scenario: scenario));
    if (scenario.kind == TalkKind.written) await begin();
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
    _scriptTimer?.cancel();
    _notesTimer?.cancel();
    _afterLine = null;
    _playback.stop();
    return super.close();
  }
}
