import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Where the video stands, as a screen follows it.
final class VideoSnapshot extends Equatable {
  const VideoSnapshot({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedTo = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.ready = false,
    this.failed = false,
    this.ended = false,
  });

  final Duration position;
  final Duration duration;
  final Duration bufferedTo;
  final bool playing;
  final bool buffering;
  final bool ready;
  final bool failed;
  final bool ended;

  @override
  List<Object?> get props => [
    position,
    duration,
    bufferedTo,
    playing,
    buffering,
    ready,
    failed,
    ended,
  ];
}

/// Plays one video at a time, so a screen and its tests don't know the player
/// behind it (ADR 15). Opening another source replaces the one playing.
abstract interface class VideoEngine {
  Stream<VideoSnapshot> get changes;

  Future<void> open(
    String url, {
    Duration from = Duration.zero,
    double speed = 1,
    bool play = true,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> setSpeed(double speed);

  /// The picture, which follows whatever is open.
  Widget view();

  Future<void> dispose();
}
