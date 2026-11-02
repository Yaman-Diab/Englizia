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

final class GrammarVideo extends Equatable {
  const GrammarVideo({
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

/// A piece of English in the rule, [strong] where the rule shows.
final class RulePart extends Equatable {
  const RulePart(this.text, {this.strong = false, this.marked = false});

  final String text;
  final bool strong;

  /// The very letters the rule is about.
  final bool marked;

  @override
  List<Object?> get props => [text, strong, marked];
}

/// A row of the rule's table: who, and what the verb does.
final class RuleRow extends Equatable {
  const RuleRow({required this.left, required this.right});

  final String left;
  final List<RulePart> right;

  @override
  List<Object?> get props => [left, right];
}

final class RuleExample extends Equatable {
  const RuleExample({required this.parts, required this.arabic, this.audioUrl});

  final List<RulePart> parts;
  final String arabic;
  final String? audioUrl;

  String get english => parts.map((part) => part.text).join();

  @override
  List<Object?> get props => [parts, arabic, audioUrl];
}

final class RuleSummary extends Equatable {
  const RuleSummary({
    required this.text,
    this.rows = const [],
    this.examples = const [],
  });

  /// Arabic, short.
  final String text;
  final List<RuleRow> rows;
  final List<RuleExample> examples;

  @override
  List<Object?> get props => [text, rows, examples];
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

/// What a grammar lesson shows before its exercises (S §8.1).
final class GrammarContent extends Equatable {
  const GrammarContent({
    required this.summary,
    required this.requiredPercent,
    this.video,
    this.teacherName,
    this.teacherAvatar,
    this.bookPage,
    this.exercisesOpen = false,
    this.questionsEnabled = false,
    this.savedWatch,
  });

  final RuleSummary summary;

  /// Of the video really watched, from the panel.
  final int requiredPercent;

  /// None: a lesson with no video, whose exercises are open from the start.
  final GrammarVideo? video;
  final String? teacherName;
  final String? teacherAvatar;
  final int? bookPage;

  /// The server lets the learner on without watching, as when the video is gone.
  final bool exercisesOpen;

  /// By the track, level and lesson, and never for kids (S §17).
  final bool questionsEnabled;

  /// As the server last heard, from any phone.
  final WatchState? savedWatch;

  @override
  List<Object?> get props => [
    summary,
    requiredPercent,
    video,
    teacherName,
    teacherAvatar,
    bookPage,
    exercisesOpen,
    questionsEnabled,
    savedWatch,
  ];
}
