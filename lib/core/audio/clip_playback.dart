import 'dart:async';

import 'package:englizia/core/audio/clip_player.dart';

/// Where a question's clip stands, as a screen shows it.
enum ClipStatus { idle, loading, playing, failed }

/// What became of a clip that was asked for.
sealed class ClipOutcome {
  const ClipOutcome();
}

/// It plays for [length], allowing for its speed.
final class ClipPlaying extends ClipOutcome {
  const ClipPlaying(this.length);

  final Duration length;
}

/// It can't be played.
final class ClipUnavailable extends ClipOutcome {
  const ClipUnavailable();
}

/// Stopped while it was loading: nothing to show for it.
final class ClipCancelled extends ClipOutcome {
  const ClipCancelled();
}

/// One screen's clip: one at a time, and one still loading can't start after it
/// was stopped or the question moved on. The screen keeps what it shows.
final class ClipPlayback {
  ClipPlayback(this._player);

  final ClipPlayer _player;
  Timer? _end;
  var _token = 0;
  var _playing = false;

  /// Plays the clip at [url], and calls [onEnd] if it runs to its end.
  Future<ClipOutcome> start(
    String url, {
    required void Function() onEnd,
    double speed = 1,
  }) async {
    stop();
    final token = _token;
    final length = await _player.load(url);
    if (token != _token) return const ClipCancelled();
    if (length == null) return const ClipUnavailable();
    final played = Duration(
      microseconds: (length.inMicroseconds / speed).round(),
    );
    _playing = true;
    unawaited(_player.play(speed: speed));
    _end = Timer(played, () {
      _playing = false;
      _end = null;
      onEnd();
    });
    return ClipPlaying(played);
  }

  /// Stops what plays, and cancels what is loading.
  void stop() {
    _token++;
    _end?.cancel();
    _end = null;
    if (_playing) {
      _playing = false;
      unawaited(_player.stop());
    }
  }
}
