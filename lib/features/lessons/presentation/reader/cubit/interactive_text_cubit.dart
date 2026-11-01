import 'dart:async';

import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/reader_cubit.dart';

/// An interactive text (requirements v3.0 §8.2–§8.3, design "Interactive Text"):
/// the reader over a sound, completed by reaching its end.
class InteractiveTextCubit extends ReaderCubit {
  InteractiveTextCubit(super.lessons, super.engine, {required super.lessonId});

  /// The speeds, in the order the button goes through them.
  static const _speeds = [1.0, 1.25, .75];

  int _lessonVersion = 0;
  bool _endToldServer = false;

  @override
  bool get stopsEachSentence => state.prefs.stopEachSentence;

  @override
  ReaderState readyState(
    ReaderState ready,
    Lesson lesson,
    ReaderContent content,
  ) {
    _lessonVersion = lesson.version;
    return ready.copyWith(showTip: !lessons.readerTipSeen);
  }

  @override
  void follow(VideoSnapshot snapshot) {
    if (isClosed) return;
    if (snapshot.failed) {
      opened = false;
      emit(state.copyWith(audioFailed: true, playing: false));
      return;
    }
    if (!snapshot.ready) return;
    if (snapshot.playing != state.playing) {
      emit(state.copyWith(playing: snapshot.playing));
    }
    syncTime(snapshot);
    if (snapshot.ended) finish();
  }

  @override
  Future<void> openMedia(Duration at) =>
      engine.open(state.content!.audioUrl, from: at, speed: state.speed);

  @override
  void onFinished() => reachedEnd();

  /// The end of the text was reached, which is what completes it (S §8.3).
  void reachedEnd() {
    if (_endToldServer) return;
    _endToldServer = true;
    unawaited(lessons.sendContentDone(lessonId, _lessonVersion));
  }

  /// «استمع» under a sentence: that one alone.
  Future<void> listenTo(int sentence) {
    final target = state.content!.sentences[sentence];
    stopAt = target.end;
    emit(state.copyWith(position: target.start, current: sentence));
    return startPlaying(from: target.start);
  }

  /// A sentence pressed becomes the current one, and the sound goes there.
  @override
  Future<void> goTo(int sentence) async {
    final target = state.content!.sentences[sentence];
    stopAt = null;
    emit(
      state.copyWith(
        position: target.start,
        current: sentence,
        word: () => null,
      ),
    );
    if (opened) await engine.seekTo(target.start);
  }

  Future<void> cycleSpeed() async {
    final speed = _speeds[(_speeds.indexOf(state.speed) + 1) % _speeds.length];
    emit(state.copyWith(speed: speed));
    if (opened) await engine.setSpeed(speed);
  }

  /// «إعادة المحاولة».
  Future<void> retryAudio() async {
    emit(state.copyWith(audioFailed: false));
    await startPlaying();
  }
}
