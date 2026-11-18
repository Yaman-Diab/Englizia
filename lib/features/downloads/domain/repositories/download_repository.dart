import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/downloads/domain/entities/lesson_download.dart';

/// Lessons kept on the phone to open with no connection (ADR 22): sealed in
/// the app's own folder, within the panel's limits, for a while.
abstract interface class DownloadRepository {
  /// False when the panel doesn't offer downloads or the phone can't keep
  /// them: nothing about them is then shown.
  Future<bool> available();

  /// Every download as it stands now.
  List<LessonDownload> get downloads;

  /// Each change of [downloads].
  Stream<List<LessonDownload>> get changes;

  /// What [lessons] would take, and whether they fit.
  Future<Result<DownloadEstimate>> estimate(List<DownloadRequest> lessons);

  /// Queues [lessons]; they are fetched one after another. Never fails: a
  /// lesson that can't be kept says why in its own state.
  Future<void> start(List<DownloadRequest> lessons);

  /// Stops a download and removes it, or removes a kept lesson.
  Future<void> remove(String lessonId);

  Future<void> removeAll();

  Future<Result<DownloadUsage>> usage();

  /// «عبر Wi-Fi فقط», on until the learner turns it off.
  bool get wifiOnly;

  Future<void> setWifiOnly({required bool on});

  /// Tells which lessons the server counts as completed, so their downloads
  /// can make room after a while.
  Future<void> markDone(Set<String> lessonIds);

  /// At startup and whenever the connection returns: carries on what was cut,
  /// asks the server again about what ran out, and removes what is no longer
  /// wanted.
  Future<void> tidy();
}
