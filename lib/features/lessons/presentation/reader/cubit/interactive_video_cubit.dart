import 'dart:async';

import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/domain/services/watch_keeper.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/reader_cubit.dart';
import 'package:englizia/features/lessons/presentation/video/player_contract.dart';

/// An interactive video (requirements v3.0 §8.4, design "Interactive Video"): the
/// reader with a video as its time, and no text over the picture. Nothing plays by
/// itself, and it is completed by how much was really watched.
class InteractiveVideoCubit extends ReaderCubit implements PlayerActions {
  InteractiveVideoCubit(super.lessons, super.engine, {required super.lessonId});

  static const _speeds = [.5, .75, 1.0, 1.25, 1.5];
  static const _skip = Duration(seconds: 10);
  static const _slowAfter = Duration(seconds: 5);

  /// A sentence gone to starts a little before its first word (S §8.4).
  static const _jumpEarly = Duration(milliseconds: 200);

  /// The next sentence takes over just before it is said.
  static const _takeOverEarly = Duration(milliseconds: 150);

  WatchKeeper? _watch;
  Timer? _slow;
  Duration _reported = Duration.zero;
  int _requiredPercent = 100;
  bool _completionSent = false;
  bool _endSent = false;

  @override
  bool get stopsEachSentence => false;

  @override
  String? get videoId => state.video?.id;

  @override
  List<double> get speeds => _speeds;

  @override
  ReaderState readyState(
    ReaderState ready,
    Lesson lesson,
    ReaderContent content,
  ) {
    final video = content.video;
    if (video == null) return ready;
    final watch = WatchKeeper(
      lessons,
      lessonId: lessonId,
      lessonVersion: lesson.version,
      video: video.video,
      fromServer: video.savedWatch,
    );
    _watch = watch;
    _requiredPercent = video.requiredPercent;
    _completionSent = watch.progress.reached(_requiredPercent);
    final from = watch.resumeFrom;
    _reported = from;
    return ready.copyWith(
      position: from,
      current: content.placeAt(from).sentence,
      resumeFrom: () => from > Duration.zero ? from : null,
      speed: video.defaultSpeed,
      quality: lessons.videoQuality,
    );
  }

  /// The sentence stays through the silence after it, as the picture still shows it.
  @override
  ReaderPlace placeAt(ReaderContent content, Duration position) {
    final place = content.placeAt(position);
    final next = content.sentences[place.sentence];
    if (place.sentence == state.current + 1 &&
        position < next.start - _takeOverEarly) {
      return (sentence: state.current, word: null);
    }
    return place;
  }

  @override
  void follow(VideoSnapshot snapshot) {
    if (isClosed) return;
    if (snapshot.failed) {
      _slow?.cancel();
      opened = false;
      emit(
        state.copyWith(
          stage: VideoStage.failed,
          playing: false,
          buffering: false,
          slowConnection: false,
        ),
      );
      return;
    }
    if (!snapshot.ready) return;
    final watch = _watch;
    if (watch != null && snapshot.playing && !snapshot.buffering) {
      watch.played(_reported, snapshot.position, speed: state.speed);
    }
    _reported = snapshot.position;
    if (snapshot.buffering && !state.buffering) {
      _watchForSlow();
    } else if (!snapshot.buffering && state.buffering) {
      _slow?.cancel();
    }
    emit(
      state.copyWith(
        bufferedTo: snapshot.bufferedTo,
        playing: snapshot.playing,
        buffering: snapshot.buffering,
        slowConnection: snapshot.buffering ? null : false,
      ),
    );
    syncTime(snapshot);
    _keepWatch(watch);
    if (snapshot.ended) finish();
  }

  void _keepWatch(WatchKeeper? watch) {
    if (watch == null) return;
    if (!_completionSent && watch.progress.reached(_requiredPercent)) {
      _completionSent = true;
      unawaited(watch.keep(state.position, send: true));
    } else if (watch.dueForSaving) {
      unawaited(watch.keep(state.position));
    }
  }

  void _watchForSlow() {
    _slow?.cancel();
    _slow = Timer(_slowAfter, () {
      if (!isClosed && state.buffering) {
        emit(state.copyWith(slowConnection: true));
      }
    });
  }

  @override
  Future<void> openMedia(Duration at) => _open(from: at);

  Future<void> _open({required Duration from, bool play = true}) async {
    final video = state.video;
    if (video == null) return;
    opened = true;
    _reported = from;
    emit(
      state.copyWith(
        stage: VideoStage.playing,
        resumeFrom: () => null,
        started: true,
        position: from,
        buffering: true,
        slowConnection: false,
      ),
    );
    _watchForSlow();
    await engine.open(
      video.urlFor(state.quality),
      from: from,
      speed: state.speed,
      play: play,
    );
  }

  @override
  void onFinished() {
    if (_endSent) return;
    _endSent = true;
    unawaited(_watch?.keep(state.duration, send: true) ?? Future.value());
  }

  /// A sentence pressed, or «أعد الجملة»: it plays from just before that sentence.
  @override
  Future<void> goTo(int sentence) {
    final start = state.content!.sentences[sentence].start;
    final from = start > _jumpEarly ? start - _jumpEarly : Duration.zero;
    stopAt = null;
    emit(state.copyWith(current: sentence, word: () => null));
    return startPlaying(from: from);
  }

  @override
  Future<void> pause() async {
    await super.pause();
    await _watch?.keep(state.position, send: true);
  }

  @override
  Future<void> playFromStart() {
    stopAt = null;
    emit(state.copyWith(current: 0, word: () => null));
    if (!opened) return startPlaying(from: Duration.zero);
    return _open(from: Duration.zero);
  }

  /// Short of the very end, which would finish it.
  @override
  Future<void> seekTo(Duration position) {
    final last = state.duration - const Duration(milliseconds: 100);
    return super.seekTo(
      position < Duration.zero
          ? Duration.zero
          : position > last
          ? last
          : position,
    );
  }

  @override
  Future<void> skipBack() => seekTo(state.position - _skip);

  @override
  Future<void> skipForward() => seekTo(state.position + _skip);

  /// There are no captions over the picture (S §8.4).
  @override
  void toggleCaptions() {}

  @override
  Future<void> setSpeed(double speed) async {
    emit(state.copyWith(speed: speed));
    if (opened) await engine.setSpeed(speed);
  }

  /// Remembered for the next video too (S §8.1).
  @override
  Future<void> setQuality(VideoQuality quality) async {
    if (quality == state.quality) return;
    emit(state.copyWith(quality: quality));
    await lessons.setVideoQuality(quality);
    if (opened) await _open(from: state.position, play: state.playing);
  }

  /// «جودة أقل», when it is slow to load.
  @override
  Future<void> lowerQuality() => setQuality(VideoQuality.low);

  /// «إعادة المحاولة».
  @override
  Future<void> retry() => _open(from: state.position);

  /// How the text shows, kept apart from an interactive text's.
  Future<void> setMode(ReaderMode mode) =>
      setPrefs(state.prefs.copyWith(videoMode: mode));

  @override
  Future<void> close() async {
    _slow?.cancel();
    if (opened) await _watch?.keep(state.position, send: true);
    return super.close();
  }
}
