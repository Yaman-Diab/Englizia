/// Plays a clip from the server, such as a listening question. Unlike
/// [SoundPlayer], the learner waits on it, so a failure is reported.
abstract interface class ClipPlayer {
  /// Gets the clip at [url] ready and returns its length; null when it can't
  /// be played.
  Future<Duration?> load(String url);

  /// Plays the clip just loaded; [speed] 0.75 is the same file, slower.
  Future<void> play({double speed = 1});

  Future<void> stop();
}

/// The app makes no sound yet (STATUS D-050): takes as long as a clip would.
final class SilentClipPlayer implements ClipPlayer {
  SilentClipPlayer({this.failsFirstLoad = false, this.latency = Duration.zero});

  /// ASSUMPTION(design): the length of the design's sample clip.
  static const clipLength = Duration(milliseconds: 4200);

  /// For mock mode, so the screen's failure can be seen once.
  bool failsFirstLoad;
  final Duration latency;

  @override
  Future<Duration?> load(String url) async {
    await Future<void>.delayed(latency);
    if (failsFirstLoad) {
      failsFirstLoad = false;
      return null;
    }
    return clipLength;
  }

  @override
  Future<void> play({double speed = 1}) async {}

  @override
  Future<void> stop() async {}
}
