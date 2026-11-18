import 'package:equatable/equatable.dart';

/// Where a lesson's download stands.
enum DownloadStatus {
  /// Waiting its turn, or for Wi-Fi.
  queued,
  downloading,

  /// On the phone: it opens with no connection.
  done,

  /// Stopped by [LessonDownload.problem]; what arrived is kept for the retry.
  failed,
}

/// Why a download stopped or waits.
enum DownloadProblem {
  /// The connection dropped or the file's host didn't answer.
  network,

  /// «عبر Wi-Fi فقط» is on and the phone is on mobile data.
  waitingForWifi,

  /// The panel's room for downloads is used up.
  overLimit,

  /// As many lessons as the panel allows are already kept.
  tooManyLessons,

  /// The phone itself has too little room left.
  noRoom,

  /// The server doesn't offer this lesson for download.
  refused,

  /// Its video comes in a form the phone can't keep.
  unsupported,
}

/// What the unit screen knows of a lesson it asks to download.
final class DownloadRequest extends Equatable {
  const DownloadRequest({
    required this.lessonId,
    required this.title,
    this.unitTitle = '',
  });

  final String lessonId;
  final String title;
  final String unitTitle;

  @override
  List<Object?> get props => [lessonId, title, unitTitle];
}

/// A lesson kept, or being kept, to open with no connection (ADR 22).
final class LessonDownload extends Equatable {
  const LessonDownload({
    required this.lessonId,
    required this.title,
    required this.status,
    this.unitTitle = '',
    this.bytes = 0,
    this.received = 0,
    this.problem,
    this.savedAt,
    this.expiresAt,
  });

  final String lessonId;
  final String title;
  final String unitTitle;
  final DownloadStatus status;

  /// Its size as the server gives it; 0 until the server has said.
  final int bytes;

  /// How much is on the phone so far.
  final int received;
  final DownloadProblem? problem;
  final DateTime? savedAt;

  /// After this it opens offline only once the server was asked again.
  final DateTime? expiresAt;

  /// 0 to 1, or null while the size isn't known.
  double? get progress => switch (status) {
    DownloadStatus.done => 1,
    _ when bytes <= 0 => null,
    _ => (received / bytes).clamp(0, 1).toDouble(),
  };

  bool get active =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  bool expiredAt(DateTime now) =>
      status == DownloadStatus.done &&
      expiresAt != null &&
      !now.isBefore(expiresAt!);

  @override
  List<Object?> get props => [
    lessonId,
    title,
    unitTitle,
    status,
    bytes,
    received,
    problem,
    savedAt,
    expiresAt,
  ];
}

/// What asking for [lessons] more would take, before anything is fetched.
final class DownloadEstimate extends Equatable {
  const DownloadEstimate({
    required this.lessons,
    required this.bytes,
    required this.usage,
    this.problem,
  });

  /// How many of the lessons asked for can be downloaded.
  final int lessons;
  final int bytes;
  final DownloadUsage usage;

  /// Set when they don't fit: the download isn't offered.
  final DownloadProblem? problem;

  @override
  List<Object?> get props => [lessons, bytes, usage, problem];
}

/// The room downloads take against what the panel and the phone allow.
final class DownloadUsage extends Equatable {
  const DownloadUsage({
    required this.usedBytes,
    required this.maxBytes,
    required this.lessons,
    required this.maxLessons,
    this.freeBytes,
  });

  final int usedBytes;
  final int maxBytes;
  final int lessons;
  final int maxLessons;

  /// The phone's own room left; null when it doesn't say.
  final int? freeBytes;

  /// 0 to 1 of the panel's room.
  double get share =>
      maxBytes <= 0 ? 0 : (usedBytes / maxBytes).clamp(0, 1).toDouble();

  @override
  List<Object?> get props => [
    usedBytes,
    maxBytes,
    lessons,
    maxLessons,
    freeBytes,
  ];
}
