import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/domain/services/watch_progress.dart';

/// A lesson's watching: counted from what played, kept on the phone now and then,
/// and sent when it matters. A replaced video starts over.
final class WatchKeeper {
  WatchKeeper(
    this._lessons, {
    required this.lessonId,
    required this.lessonVersion,
    required this.video,
    WatchState? fromServer,
  }) {
    for (final saved in [_lessons.savedWatch(lessonId), fromServer]) {
      if (saved?.videoId == video.id) {
        _saved = saved;
        break;
      }
    }
    progress = WatchProgress(
      video.duration,
      ranges: _saved?.ranges ?? const [],
    );
    _savedAt = progress.seconds;
  }

  static const _saveEvery = 5;

  /// A jump bigger than this, for its speed, was a seek and not watching.
  static const _longestStep = Duration(seconds: 3);

  final LessonRepository _lessons;
  final String lessonId;
  final int lessonVersion;
  final LessonVideo video;
  late final WatchProgress progress;
  WatchState? _saved;
  int _savedAt = 0;

  /// Where the learner stopped last time.
  Duration get resumeFrom => Duration(seconds: _saved?.positionSeconds ?? 0);

  /// The video reported going from [from] to [to].
  void played(Duration from, Duration to, {required double speed}) {
    final step = to - from;
    if (step > Duration.zero &&
        step <= _longestStep * (speed < 1 ? 1 : speed)) {
      progress.watched(from, to);
    }
  }

  bool get dueForSaving => progress.seconds - _savedAt >= _saveEvery;

  Future<void> keep(Duration position, {bool send = false}) async {
    _savedAt = progress.seconds;
    final saved = progress.stateAt(video.id, position);
    await _lessons.saveWatch(lessonId, saved);
    if (send) await _lessons.sendWatch(lessonId, lessonVersion, saved);
  }
}
