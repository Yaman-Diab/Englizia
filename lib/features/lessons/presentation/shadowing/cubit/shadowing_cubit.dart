import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';
import 'package:englizia/features/lessons/presentation/widgets/karaoke_text.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The learner's try, kept on the phone only while on its sentence (S §9).
final class ShadowingTry extends Equatable {
  const ShadowingTry({
    required this.heard,
    required this.length,
    this.levels = const [],
  });

  /// Each of the sentence's words: heard or not.
  final List<bool> heard;

  /// How long the learner spoke.
  final Duration length;

  /// The microphone's level along the way, 0 to 1, for comparing.
  final List<double> levels;

  int get count => heard.where((word) => word).length;

  @override
  List<Object?> get props => [heard, length, levels];
}

enum ComparePart { you, model }

/// «قارن»: the learner's try, then the model, the same way.
final class ShadowingCompare extends Equatable {
  const ShadowingCompare(this.part, this.run);

  final ComparePart part;
  final SoundRun run;

  @override
  List<Object?> get props => [part, run];
}

final class ShadowingState extends Equatable {
  const ShadowingState({
    this.load = LoadStatus.loading,
    this.failure,
    this.title,
    this.content,
    this.order = const [],
    this.at = 0,
    this.mode = ShadowingMode.repeat,
    this.speed = 1,
    this.modelRun,
    this.attempt,
    this.counts = const [],
    this.compare,
    this.headphonesSeen = false,
    this.finished = false,
  });

  final LoadStatus load;
  final Failure? failure;
  final String? title;
  final ReaderContent? content;

  /// The sentences to practise, by their place in the content.
  final List<int> order;

  /// Which of [order] is on screen.
  final int at;
  final ShadowingMode mode;
  final double speed;

  /// The model being said.
  final SoundRun? modelRun;

  /// The last try's verdict, until another is asked for.
  final ShadowingTry? attempt;

  /// How many words each try on this sentence caught, oldest first.
  final List<int> counts;
  final ShadowingCompare? compare;

  /// «تابع بدونها» was pressed: no more asking for headphones.
  final bool headphonesSeen;

  /// Past the last sentence.
  final bool finished;

  ReaderSentence? get sentence =>
      content == null || order.isEmpty ? null : content!.sentences[order[at]];

  bool get isLast => at == order.length - 1;

  /// It is said with the model, not after it.
  bool get together => mode != ShadowingMode.repeat;

  /// Better than the try before it: both counts, for «4 ← 6».
  (int, int)? get improvement {
    if (counts.length < 2) return null;
    final before = counts[counts.length - 2];
    final now = counts.last;
    return now > before ? (before, now) : null;
  }

  ShadowingState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    String? title,
    ReaderContent? content,
    List<int>? order,
    int? at,
    ShadowingMode? mode,
    double? speed,
    SoundRun? Function()? modelRun,
    ShadowingTry? Function()? attempt,
    List<int>? counts,
    ShadowingCompare? Function()? compare,
    bool? headphonesSeen,
    bool? finished,
  }) => ShadowingState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    title: title ?? this.title,
    content: content ?? this.content,
    order: order ?? this.order,
    at: at ?? this.at,
    mode: mode ?? this.mode,
    speed: speed ?? this.speed,
    modelRun: modelRun != null ? modelRun() : this.modelRun,
    attempt: attempt != null ? attempt() : this.attempt,
    counts: counts ?? this.counts,
    compare: compare != null ? compare() : this.compare,
    headphonesSeen: headphonesSeen ?? this.headphonesSeen,
    finished: finished ?? this.finished,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    title,
    content,
    order,
    at,
    mode,
    speed,
    modelRun,
    attempt,
    counts,
    compare,
    headphonesSeen,
    finished,
  ];
}

/// Shadowing (requirements v3.0 §9, design "Shadowing"): the sentences of a
/// text or video chosen for it, one at a time, said after the model or with it,
/// and how many words were heard. Tries are unlimited and count for nothing but
/// the sentence's best; the microphone is its own cubit.
class ShadowingCubit extends Cubit<ShadowingState> {
  ShadowingCubit(this._lessons, this.engine, {required this.lessonId})
    : super(const ShadowingState());

  static const slow = .75;

  final LessonRepository _lessons;

  /// For a video's picture; the cubit only tells it what to do.
  final VideoEngine engine;
  final String lessonId;
  bool _opened = false;
  var _runs = 0;
  Timer? _modelEnd;
  Timer? _compareStep;

  Future<void> start() async {
    emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    final result = await _lessons.getLesson(lessonId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final lesson):
        final content = lesson.reader;
        final order = <int>[
          for (final (i, sentence)
              in content?.sentences.indexed ??
                  const Iterable<(int, ReaderSentence)>.empty())
            if (sentence.shadowing) i,
        ];
        if (content == null || order.isEmpty) {
          emit(
            state.copyWith(
              load: LoadStatus.failure,
              failure: () => const UnknownFailure(),
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            title: lesson.outline.title,
            content: content,
            order: order,
            mode: _lessons.readerPrefs.shadowingMode ?? content.shadowingMode,
          ),
        );
        _arrive();
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
  }

  /// A sentence shows: after the model, it is heard once first.
  void _arrive() {
    if (state.mode == ShadowingMode.repeat) unawaited(playModel());
  }

  Duration _modelLength() {
    final sentence = state.sentence!;
    return (sentence.end - sentence.start) * (1 / state.speed);
  }

  /// The sentence's part of the sound or video, at the speed chosen. Returns how
  /// long it lasts.
  Future<Duration> _sayModel() async {
    final content = state.content!;
    final sentence = state.sentence!;
    final length = _modelLength();
    _modelEnd?.cancel();
    if (!_opened) {
      _opened = true;
      final video = content.video;
      await engine.open(
        video == null
            ? content.audioUrl
            : video.video.urlFor(_lessons.videoQuality),
        from: sentence.start,
        speed: state.speed,
      );
    } else {
      await engine.seekTo(sentence.start);
      await engine.play();
    }
    return length;
  }

  void _silence() {
    _modelEnd?.cancel();
    if (_opened) unawaited(engine.pause());
  }

  /// «استمع للنموذج», or a sentence arriving in «كرّر بعدي».
  Future<void> playModel() async {
    _compareStep?.cancel();
    emit(
      state.copyWith(
        modelRun: () => SoundRun(++_runs, _modelLength()),
        compare: () => null,
      ),
    );
    final length = await _sayModel();
    if (isClosed) return;
    _modelEnd = Timer(length, () {
      if (isClosed) return;
      unawaited(engine.pause());
      emit(state.copyWith(modelRun: () => null));
    });
  }

  void stopModel() {
    _silence();
    if (state.modelRun != null) emit(state.copyWith(modelRun: () => null));
  }

  /// The microphone opens with the model: how long to listen for.
  Duration startTogether() {
    unawaited(playModel());
    return _modelLength();
  }

  /// What the microphone caught on this try.
  void heard(
    String transcript, {
    required Duration length,
    List<double> levels = const [],
  }) {
    stopModel();
    final words = [for (final word in state.sentence!.words) word.text];
    final attempt = ShadowingTry(
      heard: heardWords(words, transcript),
      length: length,
      levels: levels,
    );
    emit(
      state.copyWith(
        attempt: () => attempt,
        counts: [...state.counts, attempt.count],
        compare: () => null,
      ),
    );
  }

  /// «أعد المحاولة».
  void retry() {
    _compareStep?.cancel();
    stopModel();
    emit(state.copyWith(attempt: () => null, compare: () => null));
    _arrive();
  }

  /// «قارن»: the try, then the model, each with its line running across it.
  void compare() {
    final attempt = state.attempt;
    if (attempt == null) return;
    stopModel();
    _compareStep?.cancel();
    emit(
      state.copyWith(
        compare: () => ShadowingCompare(
          ComparePart.you,
          SoundRun(++_runs, attempt.length),
        ),
      ),
    );
    _compareStep = Timer(attempt.length, () async {
      if (isClosed) return;
      final length = _modelLength();
      emit(
        state.copyWith(
          compare: () =>
              ShadowingCompare(ComparePart.model, SoundRun(++_runs, length)),
        ),
      );
      await _sayModel();
      if (isClosed) return;
      _compareStep = Timer(length, () {
        if (isClosed) return;
        _silence();
        emit(state.copyWith(compare: () => null));
      });
    });
  }

  Future<void> setMode(ShadowingMode mode) async {
    if (mode == state.mode) return;
    _compareStep?.cancel();
    stopModel();
    emit(
      state.copyWith(
        mode: mode,
        attempt: () => null,
        counts: const [],
        compare: () => null,
      ),
    );
    await _lessons.setReaderPrefs(
      _lessons.readerPrefs.copyWith(shadowingMode: mode),
    );
    if (!isClosed) _arrive();
  }

  Future<void> setSpeed(double speed) async {
    emit(state.copyWith(speed: speed));
    if (_opened) await engine.setSpeed(speed);
  }

  void dismissHeadphones() => emit(state.copyWith(headphonesSeen: true));

  /// The sentence's best goes to the server, once it is left.
  void _keepBest() {
    final sentence = state.sentence;
    if (sentence == null || state.counts.isEmpty) return;
    final best = state.counts.reduce((a, b) => a > b ? a : b);
    unawaited(
      _lessons.saveShadowingScore(
        ShadowingScore(
          lessonId: lessonId,
          sentenceId: sentence.id,
          heard: best,
          total: sentence.words.length,
        ),
      ),
    );
  }

  /// «التالي», «الجملة التالية», or after the last «متابعة إلى التمارين».
  void next() {
    _compareStep?.cancel();
    stopModel();
    _keepBest();
    if (state.isLast) {
      emit(state.copyWith(counts: const [], finished: true));
      return;
    }
    emit(
      state.copyWith(
        at: state.at + 1,
        attempt: () => null,
        counts: const [],
        compare: () => null,
      ),
    );
    _arrive();
  }

  @override
  Future<void> close() async {
    _modelEnd?.cancel();
    _compareStep?.cancel();
    _keepBest();
    await engine.dispose();
    return super.close();
  }
}
