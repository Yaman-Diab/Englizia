import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class LessonCompleteState extends Equatable {
  const LessonCompleteState({
    required this.summary,
    this.result,
    this.late = false,
  });

  /// What the phone counted.
  final LessonSummary summary;

  /// What the server says, once it has.
  final LessonResult? result;

  /// The server hasn't answered in time, or can't be reached: the points are
  /// counted later (design: over two seconds, or no connection).
  final bool late;

  LessonOutline get _outline => summary.outline;

  bool get waitingForServer => result == null && late;

  bool get replay => result?.replay ?? _outline.replay;

  int get rightFirstTime => result?.rightFirstTime ?? summary.rightFirstTime;

  int get counted => result?.counted ?? summary.counted;

  int get seconds => result?.seconds ?? summary.seconds;

  int get pending => result?.pending ?? summary.pending;

  bool get perfect => counted > 0 && rightFirstTime == counted && pending == 0;

  NextStep? get next => result?.next ?? _outline.next;

  /// Whether the points have a place: until the server says, as the lesson does.
  bool get showsXp => result == null ? _outline.earnsXp : result!.xp != null;

  /// This lesson's step is done, even before the server says so.
  UnitProgress? get unit =>
      result?.unit ?? _outline.unit?.withDone(summary.lessonId);

  /// The last lesson of its unit was just finished.
  bool get unitDone =>
      !replay && unit != null && next != null && next!.kind != NextKind.lesson;

  LessonCompleteState copyWith({LessonResult? result, bool? late}) =>
      LessonCompleteState(
        summary: summary,
        result: result ?? this.result,
        late: late ?? this.late,
      );

  @override
  List<Object?> get props => [summary, result, late];
}

/// The end of a lesson (requirements v3.0 §7.6, design "Lesson Complete"): shows
/// what the phone knows at once, and asks the server for the official numbers.
/// A completion that can't be sent stays on the phone, like an answer.
class LessonCompleteCubit extends Cubit<LessonCompleteState> {
  LessonCompleteCubit(
    this._lessons,
    this._connectivity,
    this._sounds, {
    required LessonSummary summary,
  }) : super(LessonCompleteState(summary: summary));

  static const _lateAfter = Duration(seconds: 2);

  final LessonRepository _lessons;
  final ConnectivityService _connectivity;
  final SoundPlayer _sounds;
  StreamSubscription<bool>? _connection;
  Timer? _late;
  bool _asking = false;

  Future<void> start() async {
    unawaited(_sounds.play(AppSound.lessonComplete));
    _connection = _connectivity.onlineChanges.listen((online) {
      if (online && state.result == null) unawaited(_ask());
    });
    _late = Timer(_lateAfter, () {
      if (!isClosed) emit(state.copyWith(late: true));
    });
    await _ask();
  }

  Future<void> _ask() async {
    if (_asking) return;
    _asking = true;
    final answer = await _lessons.completeLesson(state.summary);
    _asking = false;
    if (isClosed) return;
    _late?.cancel();
    switch (answer) {
      case Ok(:final value):
        emit(state.copyWith(result: value));
        if (value.goal?.justMet ?? false) {
          unawaited(_sounds.play(AppSound.goalReached));
        }
      case Err():
        emit(state.copyWith(late: true));
    }
  }

  @override
  Future<void> close() async {
    _late?.cancel();
    await _connection?.cancel();
    return super.close();
  }
}
