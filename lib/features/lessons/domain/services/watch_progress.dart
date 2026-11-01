import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';

/// The seconds of a video really watched: dragging to the end counts for nothing
/// (S §8.1), and watching a part twice counts once.
final class WatchProgress {
  WatchProgress(this.total, {List<(int, int)> ranges = const []}) {
    for (final (from, to) in ranges) {
      for (var second = from; second < to; second++) {
        _seen.add(second);
      }
    }
  }

  final Duration total;
  final _seen = <int>{};

  /// The video played from [from] to [to].
  void watched(Duration from, Duration to) {
    for (var s = from.inSeconds; s < to.inSeconds; s++) {
      if (s < total.inSeconds) _seen.add(s);
    }
  }

  int get seconds => _seen.length;

  int get percent =>
      total.inSeconds == 0 ? 0 : (seconds * 100 / total.inSeconds).round();

  bool reached(int requiredPercent) =>
      total.inSeconds > 0 && seconds * 100 >= requiredPercent * total.inSeconds;

  List<(int, int)> get ranges {
    final sorted = _seen.toList()..sort();
    final ranges = <(int, int)>[];
    for (final second in sorted) {
      if (ranges.isNotEmpty && ranges.last.$2 == second) {
        ranges.last = (ranges.last.$1, second + 1);
      } else {
        ranges.add((second, second + 1));
      }
    }
    return ranges;
  }

  WatchState stateAt(String videoId, Duration position) => WatchState(
    videoId: videoId,
    positionSeconds: position.inSeconds,
    ranges: ranges,
  );
}
