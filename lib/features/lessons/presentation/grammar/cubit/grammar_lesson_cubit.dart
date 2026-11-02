import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/domain/services/watch_progress.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum VideoStage { cover, playing, failed }

final class GrammarLessonState extends Equatable {
  const GrammarLessonState({
    this.load = LoadStatus.loading,
    this.failure,
    this.lessonTitle,
    this.content,
    this.stage = VideoStage.cover,
    this.resumeFrom,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedTo = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.slowConnection = false,
    this.watchedPercent = 0,
    this.unlocked = false,
    this.celebrating = false,
    this.captions = false,
    this.speed = 1,
    this.quality = VideoQuality.auto,
    this.saying,
  });

  final LoadStatus load;
  final Failure? failure;
  final String? lessonTitle;
  final GrammarContent? content;
  final VideoStage stage;

  /// Where the learner stopped last time: «توقفت عند 2:14», until they choose.
  final Duration? resumeFrom;
  final Duration position;
  final Duration duration;
  final Duration bufferedTo;
  final bool playing;
  final bool buffering;

  /// Still loading after a while: a lower quality is offered.
  final bool slowConnection;
  final int watchedPercent;

  /// Enough was really watched, or the lesson asks for no watching.
  final bool unlocked;

  /// «يمكنك الآن بدء التمارين» shows for a moment.
  final bool celebrating;
  final bool captions;
  final double speed;
  final VideoQuality quality;

  /// Which example of the rule is being said.
  final int? saying;

  GrammarVideo? get video => content?.video;

  String? get caption => captions ? video?.captionAt(position) : null;

  bool get started => watchedPercent > 0 || stage == VideoStage.playing;

  GrammarLessonState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    String? lessonTitle,
    GrammarContent? content,
    VideoStage? stage,
    Duration? Function()? resumeFrom,
    Duration? position,
    Duration? duration,
    Duration? bufferedTo,
    bool? playing,
    bool? buffering,
    bool? slowConnection,
    int? watchedPercent,
    bool? unlocked,
    bool? celebrating,
    bool? captions,
    double? speed,
    VideoQuality? quality,
    int? Function()? saying,
  }) => GrammarLessonState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    lessonTitle: lessonTitle ?? this.lessonTitle,
    content: content ?? this.content,
    stage: stage ?? this.stage,
    resumeFrom: resumeFrom != null ? resumeFrom() : this.resumeFrom,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    bufferedTo: bufferedTo ?? this.bufferedTo,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    slowConnection: slowConnection ?? this.slowConnection,
    watchedPercent: watchedPercent ?? this.watchedPercent,
    unlocked: unlocked ?? this.unlocked,
    celebrating: celebrating ?? this.celebrating,
    captions: captions ?? this.captions,
    speed: speed ?? this.speed,
    quality: quality ?? this.quality,
    saying: saying != null ? saying() : this.saying,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    lessonTitle,
    content,
    stage,
    resumeFrom,
    position,
    duration,
    bufferedTo,
    playing,
    buffering,
    slowConnection,
    watchedPercent,
    unlocked,
    celebrating,
    captions,
    speed,
    quality,
    saying,
  ];
}

/// A grammar lesson before its exercises (requirements v3.0 §8.1, design "Grammar
/// Video"): nothing plays by itself, and the exercises open once enough was really
/// watched, which is counted from the seconds that played, not from the bar.
class GrammarLessonCubit extends Cubit<GrammarLessonState> {
  GrammarLessonCubit(
    this._lessons,
    this.engine,
    ClipPlayer player, {
    required this.lessonId,
  }) : _clip = ClipPlayback(player),
       super(const GrammarLessonState());

  static const speeds = [.75, 1.0, 1.25, 1.5];
  static const _skip = Duration(seconds: 10);
  static const _slowAfter = Duration(seconds: 5);
  static const _celebration = Duration(seconds: 6);
  static const _saveEvery = 5;

  /// A jump bigger than this, for its speed, was a seek and not watching.
  static const _longestStep = Duration(seconds: 3);

  final LessonRepository _lessons;

  /// For the page's picture; the cubit only tells it what to do.
  final VideoEngine engine;
  final ClipPlayback _clip;
  final String lessonId;

  int _lessonVersion = 0;
  WatchProgress? _watch;
  StreamSubscription<VideoSnapshot>? _changes;
  Timer? _slow;
  Timer? _celebrate;
  bool _opened = false;
  int _savedAt = 0;

  Future<void> start() async {
    emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    final result = await _lessons.getLesson(lessonId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final lesson):
        final content = lesson.grammar;
        if (content == null) {
          emit(
            state.copyWith(
              load: LoadStatus.failure,
              failure: () => const UnknownFailure(),
            ),
          );
          return;
        }
        _lessonVersion = lesson.version;
        final video = content.video;
        final saved = video == null ? null : _savedFor(video, content);
        final watch = video == null
            ? null
            : WatchProgress(video.duration, ranges: saved?.ranges ?? const []);
        _watch = watch;
        _savedAt = watch?.seconds ?? 0;
        final from = Duration(seconds: saved?.positionSeconds ?? 0);
        _changes ??= engine.changes.listen(_follow);
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            lessonTitle: lesson.outline.title,
            content: content,
            position: from,
            duration: video?.duration,
            resumeFrom: () => from > Duration.zero ? from : null,
            watchedPercent: watch?.percent ?? 0,
            unlocked:
                video == null ||
                content.exercisesOpen ||
                (watch?.reached(content.requiredPercent) ?? false),
            quality: _lessons.videoQuality,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
  }

  /// This phone's record, or the server's. A replaced video starts over.
  WatchState? _savedFor(GrammarVideo video, GrammarContent content) {
    for (final saved in [_lessons.savedWatch(lessonId), content.savedWatch]) {
      if (saved?.videoId == video.id) return saved;
    }
    return null;
  }

  void _follow(VideoSnapshot snapshot) {
    if (isClosed) return;
    if (snapshot.failed) {
      _slow?.cancel();
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
    final step = snapshot.position - state.position;
    if (watch != null &&
        snapshot.playing &&
        !snapshot.buffering &&
        step > Duration.zero &&
        step <= _longestStep * (state.speed < 1 ? 1 : state.speed)) {
      watch.watched(state.position, snapshot.position);
    }
    _followBuffering(snapshot.buffering);
    final justUnlocked =
        !state.unlocked &&
        (watch?.reached(state.content?.requiredPercent ?? 100) ?? false);
    emit(
      state.copyWith(
        position: snapshot.position,
        duration: snapshot.duration > Duration.zero ? snapshot.duration : null,
        bufferedTo: snapshot.bufferedTo,
        playing: snapshot.playing,
        buffering: snapshot.buffering,
        watchedPercent: watch?.percent,
        unlocked: justUnlocked ? true : null,
        celebrating: justUnlocked ? true : null,
      ),
    );
    if (justUnlocked) {
      _celebrate = Timer(_celebration, () {
        if (!isClosed) emit(state.copyWith(celebrating: false));
      });
      unawaited(_keepWatch(send: true));
    } else if ((watch?.seconds ?? 0) - _savedAt >= _saveEvery) {
      unawaited(_keepWatch());
    }
  }

  void _followBuffering(bool buffering) {
    if (buffering && !state.buffering) {
      _watchForSlow();
    } else if (!buffering && state.buffering) {
      _slow?.cancel();
      emit(state.copyWith(slowConnection: false));
    }
  }

  Future<void> _keepWatch({bool send = false}) async {
    final watch = _watch;
    final video = state.video;
    if (watch == null || video == null) return;
    _savedAt = watch.seconds;
    final saved = watch.stateAt(video.id, state.position);
    await _lessons.saveWatch(lessonId, saved);
    if (send) await _lessons.sendWatch(lessonId, _lessonVersion, saved);
  }

  Future<void> _open({required Duration from, bool play = true}) async {
    final video = state.video;
    if (video == null) return;
    _opened = true;
    emit(
      state.copyWith(
        stage: VideoStage.playing,
        resumeFrom: () => null,
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

  void _watchForSlow() {
    _slow?.cancel();
    _slow = Timer(_slowAfter, () {
      if (!isClosed && state.buffering) {
        emit(state.copyWith(slowConnection: true));
      }
    });
  }

  /// The big button, or «شاهد الفيديو».
  Future<void> play() async {
    await _stopExample();
    if (!_opened) return _open(from: state.resumeFrom ?? Duration.zero);
    final atEnd = state.position >= state.duration;
    if (atEnd) await engine.seekTo(Duration.zero);
    await engine.play();
  }

  /// «من البداية».
  Future<void> playFromStart() async {
    await _stopExample();
    await _open(from: Duration.zero);
  }

  Future<void> pause() async {
    await engine.pause();
    await _keepWatch(send: true);
  }

  Future<void> togglePlay() => state.playing ? pause() : play();

  Future<void> seekTo(Duration position) async {
    final end = state.duration;
    final to = position < Duration.zero
        ? Duration.zero
        : position > end
        ? end
        : position;
    emit(state.copyWith(position: to));
    await engine.seekTo(to);
  }

  Future<void> skipBack() => seekTo(state.position - _skip);

  Future<void> skipForward() => seekTo(state.position + _skip);

  void toggleCaptions() => emit(state.copyWith(captions: !state.captions));

  Future<void> setSpeed(double speed) async {
    emit(state.copyWith(speed: speed));
    await engine.setSpeed(speed);
  }

  /// Remembered for the next video too (S §8.1).
  Future<void> setQuality(VideoQuality quality) async {
    if (quality == state.quality) return;
    emit(state.copyWith(quality: quality));
    await _lessons.setVideoQuality(quality);
    if (_opened) await _open(from: state.position, play: state.playing);
  }

  /// «جودة أقل», when it is slow to load.
  Future<void> lowerQuality() => setQuality(VideoQuality.low);

  /// «إعادة المحاولة».
  Future<void> retry() => _open(from: state.position);

  /// An example of the rule said aloud, or stopped. The video waits meanwhile.
  Future<void> sayExample(int index) async {
    if (state.saying == index) return _stopExample();
    final url = state.content?.summary.examples[index].audioUrl;
    if (url == null) return;
    if (state.playing) await pause();
    _clip.stop();
    emit(state.copyWith(saying: () => index));
    final outcome = await _clip.start(
      url,
      onEnd: () {
        if (!isClosed) emit(state.copyWith(saying: () => null));
      },
    );
    if (!isClosed && outcome is ClipUnavailable) {
      emit(state.copyWith(saying: () => null));
    }
  }

  Future<void> _stopExample() async {
    _clip.stop();
    if (state.saying != null) emit(state.copyWith(saying: () => null));
  }

  @override
  Future<void> close() async {
    _slow?.cancel();
    _celebrate?.cancel();
    _clip.stop();
    await _keepWatch(send: true);
    await _changes?.cancel();
    await engine.dispose();
    return super.close();
  }
}
