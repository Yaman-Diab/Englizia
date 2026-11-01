import 'package:equatable/equatable.dart';

enum VideoQuality { auto, low, medium, high }

/// One way to get the video. The server's sizes are only a guide for the learner.
final class VideoSource extends Equatable {
  const VideoSource({required this.quality, required this.url, this.sizeMb});

  final VideoQuality quality;
  final String url;
  final int? sizeMb;

  @override
  List<Object?> get props => [quality, url, sizeMb];
}

/// A line of the Arabic captions, in seconds' worth of milliseconds.
final class VideoCaption extends Equatable {
  const VideoCaption({
    required this.from,
    required this.to,
    required this.text,
  });

  final Duration from;
  final Duration to;
  final String text;

  @override
  List<Object?> get props => [from, to, text];
}

final class LessonVideo extends Equatable {
  const LessonVideo({
    required this.id,
    required this.duration,
    required this.sources,
    this.coverUrl,
    this.captions = const [],
  });

  /// Changes when the video is replaced: the learner starts it over (S §8.1).
  final String id;
  final Duration duration;
  final List<VideoSource> sources;
  final String? coverUrl;
  final List<VideoCaption> captions;

  /// The source for [quality], or the first there is.
  String urlFor(VideoQuality quality) => sources
      .firstWhere((s) => s.quality == quality, orElse: () => sources.first)
      .url;

  String? captionAt(Duration position) {
    for (final caption in captions) {
      if (position >= caption.from && position < caption.to) {
        return caption.text;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [id, duration, sources, coverUrl, captions];
}

/// How much of a video was really watched, and where it stopped.
final class WatchState extends Equatable {
  const WatchState({
    required this.videoId,
    required this.positionSeconds,
    required this.ranges,
  });

  final String videoId;
  final int positionSeconds;

  /// Seconds watched, as `[from, to)` pairs.
  final List<(int, int)> ranges;

  @override
  List<Object?> get props => [videoId, positionSeconds, ranges];
}
