import 'dart:async';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// [VideoEngine] on Flutter's own `video_player`. While it plays the screen stays
/// on (S §8.1), through a small native channel: no keep-awake package fits the
/// Flutter pin (ADR 15).
final class VideoPlayerEngine implements VideoEngine {
  static const _screen = MethodChannel('englizia/screen_awake');

  final _changes = StreamController<VideoSnapshot>.broadcast();
  final _open = ValueNotifier<VideoPlayerController?>(null);
  bool _awake = false;
  bool _disposed = false;

  @override
  Stream<VideoSnapshot> get changes => _changes.stream;

  @override
  Future<void> open(
    String url, {
    Duration from = Duration.zero,
    double speed = 1,
    bool play = true,
  }) async {
    final old = _open.value;
    old?.removeListener(_report);
    _open.value = null;
    await old?.dispose();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }
      if (from > Duration.zero) await controller.seekTo(from);
      await controller.setPlaybackSpeed(speed);
      if (play) await controller.play();
      controller.addListener(_report);
      _open.value = controller;
      _report();
    } on Object catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'The video could not open');
      await controller.dispose();
      if (!_disposed) _changes.add(const VideoSnapshot(failed: true));
    }
  }

  void _report() {
    final controller = _open.value;
    if (controller == null || _disposed) return;
    final value = controller.value;
    _keepScreenOn(value.isPlaying);
    _changes.add(
      VideoSnapshot(
        position: value.position,
        duration: value.duration,
        bufferedTo: value.buffered.isEmpty
            ? Duration.zero
            : value.buffered.last.end,
        playing: value.isPlaying,
        buffering: value.isBuffering,
        ready: value.isInitialized,
        failed: value.hasError,
        ended: value.isCompleted,
      ),
    );
  }

  void _keepScreenOn(bool on) {
    if (on == _awake) return;
    _awake = on;
    unawaited(
      _screen.invokeMethod<void>('set', on).catchError((Object error) {
        AppLogger.error(error, StackTrace.current, 'Keeping the screen on');
      }),
    );
  }

  @override
  Future<void> play() async => _open.value?.play();

  @override
  Future<void> pause() async => _open.value?.pause();

  @override
  Future<void> seekTo(Duration position) async => _open.value?.seekTo(position);

  @override
  Future<void> setSpeed(double speed) async =>
      _open.value?.setPlaybackSpeed(speed);

  @override
  Widget view() => ValueListenableBuilder(
    valueListenable: _open,
    builder: (_, controller, _) => controller == null
        ? const SizedBox.expand()
        : Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
  );

  @override
  Future<void> dispose() async {
    _disposed = true;
    _keepScreenOn(false);
    final controller = _open.value;
    controller?.removeListener(_report);
    _open.value = null;
    await controller?.dispose();
    _open.dispose();
    await _changes.close();
  }
}
