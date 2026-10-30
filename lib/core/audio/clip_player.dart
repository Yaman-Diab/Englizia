/// Plays a clip from the server, such as a listening question. Unlike
/// [SoundPlayer], the learner waits on it, so a failure is reported.
abstract interface class ClipPlayer {
  /// Gets the clip at [url] ready and returns its length; null when it can't
  /// be played.
  Future<Duration?> load(String url);

  Future<void> play();

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
  Future<void> play() async {}

  @override
  Future<void> stop() async {}
}
