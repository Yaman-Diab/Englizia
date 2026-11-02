import 'dart:async';

import 'package:englizia/core/video/video_engine.dart';
import 'package:flutter/widgets.dart';

/// The mock's sound: no sound (D-050), but its time passes, so what follows the
/// sound can be seen. A url with `broken` in it fails, for that state to be seen.
final class SilentAudioEngine implements VideoEngine {
  static const _tick = Duration(milliseconds: 250);

  final _changes = StreamController<VideoSnapshot>.broadcast();
  Timer? _clock;
  var _position = Duration.zero;
  var _speed = 1.0;
  var _playing = false;
  var _ready = false;

  void _report() {
    if (_changes.isClosed) return;
    _changes.add(
      VideoSnapshot(position: _position, playing: _playing, ready: _ready),
    );
  }

  void _run() {
    _clock?.cancel();
    if (!_playing) return;
    _clock = Timer.periodic(_tick, (_) {
      _position += _tick * _speed;
      _report();
    });
  }

  @override
  Stream<VideoSnapshot> get changes => _changes.stream;

  @override
  Future<void> open(
    String url, {
    Duration from = Duration.zero,
    double speed = 1,
    bool play = true,
  }) async {
    if (url.contains('broken')) {
      _changes.add(const VideoSnapshot(failed: true));
      return;
    }
    _position = from;
    _speed = speed;
    _playing = play;
    _ready = true;
    _report();
    _run();
  }

  @override
  Future<void> play() async {
    _playing = true;
    _report();
    _run();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _clock?.cancel();
    _report();
  }

  @override
  Future<void> seekTo(Duration position) async {
    _position = position;
    _report();
  }

  @override
  Future<void> setSpeed(double speed) async => _speed = speed;

  @override
  Widget view() => const SizedBox.shrink();

  @override
  Future<void> dispose() async {
    _clock?.cancel();
    await _changes.close();
  }
}
