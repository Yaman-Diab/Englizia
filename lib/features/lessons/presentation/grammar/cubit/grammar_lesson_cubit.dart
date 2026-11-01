import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/domain/services/watch_keeper.dart';
import 'package:englizia/features/lessons/presentation/video/player_contract.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class GrammarLessonState extends Equatable implements PlayerState {
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
  @override
  final String? lessonTitle;
  final GrammarContent? content;
  @override
  final VideoStage stage;
  @override
  final Duration? resumeFrom;
  @override
  final Duration position;
  @override
  final Duration duration;
  @override
  final Duration bufferedTo;
  @override
  final bool playing;
  @override
  final bool buffering;
  @override
  final bool slowConnection;
  final int watchedPercent;

  /// Enough was really watched, or the lesson asks for no watching.
  final bool unlocked;

  /// «يمكنك الآن بدء التمارين» shows for a moment.
  final bool celebrating;
  @override
  final bool captions;
  @override
  final double speed;
  @override
  final VideoQuality quality;

  /// Which example of the rule is being said.
  final int? saying;

  @override
  LessonVideo? get video => content?.video;

  @override
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
class GrammarLessonCubit extends Cubit<GrammarLessonState>
    implements PlayerActions {
  GrammarLessonCubit(
    this._lessons,
    this.engine,
    ClipPlayer player, {
    required this.lessonId,
  }) : _clip = ClipPlayback(player),
       super(const GrammarLessonState());

  static const _speeds = [.75, 1.0, 1.25, 1.5];
  static const _skip = Duration(seconds: 10);
  static const _slowAfter = Duration(seconds: 5);
  static const _celebration = Duration(seconds: 6);

  final LessonRepository _lessons;

  @override
  final VideoEngine engine;
  final ClipPlayback _clip;
  final String lessonId;

  WatchKeeper? _watch;
  StreamSubscription<VideoSnapshot>? _changes;
  Timer? _slow;
  Timer? _celebrate;
  bool _opened = false;

  @override
  List<double> get speeds => _speeds;

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
        final video = content.video;
        final watch = video == null
            ? null
            : WatchKeeper(
                _lessons,
                lessonId: lessonId,
                lessonVersion: lesson.version,
                video: video,
                fromServer: content.savedWatch,
              );
        _watch = watch;
        final from = watch?.resumeFrom ?? Duration.zero;
        _changes ??= engine.changes.listen(_follow);
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            lessonTitle: lesson.outline.title,
            content: content,
            position: from,
            duration: video?.duration,
            resumeFrom: () => from > Duration.zero ? from : null,
            watchedPercent: watch?.progress.percent ?? 0,
            unlocked:
                video == null ||
                content.exercisesOpen ||
                (watch?.progress.reached(content.requiredPercent) ?? false),
            quality: _lessons.videoQuality,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
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
    if (watch != null && snapshot.playing && !snapshot.buffering) {
      watch.played(state.position, snapshot.position, speed: state.speed);
    }
    _followBuffering(snapshot.buffering);
    final justUnlocked =
        !state.unlocked &&
        (watch?.progress.reached(state.content?.requiredPercent ?? 100) ??
            false);
    emit(
      state.copyWith(
        position: snapshot.position,
        duration: snapshot.duration > Duration.zero ? snapshot.duration : null,
        bufferedTo: snapshot.bufferedTo,
        playing: snapshot.playing,
        buffering: snapshot.buffering,
        watchedPercent: watch?.progress.percent,
        unlocked: justUnlocked ? true : null,
        celebrating: justUnlocked ? true : null,
      ),
    );
    if (justUnlocked) {
      _celebrate = Timer(_celebration, () {
        if (!isClosed) emit(state.copyWith(celebrating: false));
      });
      unawaited(_keepWatch(send: true));
    } else if (watch?.dueForSaving ?? false) {
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

  Future<void> _keepWatch({bool send = false}) async =>
      _watch?.keep(state.position, send: send);

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
  @override
  Future<void> play() async {
    await _stopExample();
    if (!_opened) return _open(from: state.resumeFrom ?? Duration.zero);
    final atEnd = state.position >= state.duration;
    if (atEnd) await engine.seekTo(Duration.zero);
    await engine.play();
  }

  /// «من البداية».
  @override
  Future<void> playFromStart() async {
    await _stopExample();
    await _open(from: Duration.zero);
  }

  Future<void> pause() async {
    await engine.pause();
    await _keepWatch(send: true);
  }

  @override
  Future<void> togglePlay() => state.playing ? pause() : play();

  @override
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

  @override
  Future<void> skipBack() => seekTo(state.position - _skip);

  @override
  Future<void> skipForward() => seekTo(state.position + _skip);

  @override
  void toggleCaptions() => emit(state.copyWith(captions: !state.captions));

  @override
  Future<void> setSpeed(double speed) async {
    emit(state.copyWith(speed: speed));
    await engine.setSpeed(speed);
  }

  /// Remembered for the next video too (S §8.1).
  @override
  Future<void> setQuality(VideoQuality quality) async {
    if (quality == state.quality) return;
    emit(state.copyWith(quality: quality));
    await _lessons.setVideoQuality(quality);
    if (_opened) await _open(from: state.position, play: state.playing);
  }

  /// «جودة أقل», when it is slow to load.
  @override
  Future<void> lowerQuality() => setQuality(VideoQuality.low);

  /// «إعادة المحاولة».
  @override
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
