import 'dart:async';

import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// [ClipPlayer] on `just_audio`: one clip at a time, from the server, or
/// from the app's files where [bundled] names one (mock mode). While a clip
/// plays, the app's sounds keep quiet (ADR 9). A clip that can't load, or
/// takes longer than [timeout], is reported as unavailable, never thrown.
final class JustAudioClipPlayer implements ClipPlayer {
  JustAudioClipPlayer({
    SoundPlayer sounds = const SilentSoundPlayer(),
    String? Function(String url)? bundled,
    this.failsFirstLoad = false,
    this.timeout = const Duration(seconds: 15),
  }) : _sounds = sounds,
       _bundled = bundled;

  final SoundPlayer _sounds;
  final String? Function(String url)? _bundled;

  /// For mock mode, so the screens' failure can be seen once.
  bool failsFirstLoad;
  final Duration timeout;

  AudioPlayer? _player;
  StreamSubscription<ProcessingState>? _ended;
  VoidCallback? _quiet;

  @override
  Future<Duration?> load(String url) async {
    await stop();
    if (failsFirstLoad) {
      failsFirstLoad = false;
      return null;
    }
    try {
      final player = _player ??= AudioPlayer(
        handleAudioSessionActivation: false,
      );
      final asset = _bundled?.call(url);
      final length =
          await (asset != null ? player.setAsset(asset) : player.setUrl(url))
              .timeout(timeout);
      return length ??
          await player.durationStream
              .firstWhere((length) => length != null)
              .timeout(const Duration(seconds: 3));
    } on Object catch (error) {
      AppLogger.debug('A clip did not load: $error');
      return null;
    }
  }

  @override
  Future<void> play({double speed = 1}) async {
    final player = _player;
    if (player == null) return;
    try {
      await player.setSpeed(speed);
      await player.seek(Duration.zero);
      _quiet ??= _sounds.holdQuiet();
      await _ended?.cancel();
      _ended = player.processingStateStream
          .where((state) => state == ProcessingState.completed)
          .listen((_) => _release());
      unawaited(player.play().catchError((Object _) {}));
    } on Object catch (error) {
      _release();
      AppLogger.debug('A clip did not play: $error');
    }
  }

  @override
  Future<void> stop() async {
    _release();
    try {
      await _player?.pause();
    } on Object catch (error) {
      AppLogger.debug('A clip did not stop: $error');
    }
  }

  void _release() {
    unawaited(_ended?.cancel());
    _ended = null;
    _quiet?.call();
    _quiet = null;
  }
}
