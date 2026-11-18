import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/error/failure_mapper.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/media/device_storage.dart';
import 'package:englizia/core/media/hls_playlist.dart';
import 'package:englizia/core/media/kept_lesson.dart';
import 'package:englizia/core/media/media_vault.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/media_client.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/downloads/data/datasources/download_remote_data_source.dart';
import 'package:englizia/features/downloads/data/models/download_manifest_model.dart';
import 'package:englizia/features/downloads/domain/entities/lesson_download.dart';
import 'package:englizia/features/downloads/domain/repositories/download_repository.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';

/// Keeps lessons in the vault, one at a time and a file at a time, so a cut
/// connection loses one file at most and the next try carries on from it.
/// What is kept and how far is written in the vault too (`downloads/index`).
final class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl(
    this._remote, {
    required MediaClient client,
    required MediaVault vault,
    required SettingsStorageService settings,
    required ConnectivityService connectivity,
    required DeviceStorage storage,
    required Future<DownloadLimits?> Function() limits,
    this.canKeep = true,
    DateTime Function()? now,
  }) : _client = client,
       _vault = vault,
       _settings = settings,
       _connectivity = connectivity,
       _storage = storage,
       _limits = limits,
       _now = now ?? DateTime.now;

  static const _indexName = 'downloads/index';

  /// How much must arrive before the screen is told again.
  static const _tick = 64 * 1024;

  final DownloadRemoteDataSource _remote;
  final MediaClient _client;
  final MediaVault _vault;
  final SettingsStorageService _settings;
  final ConnectivityService _connectivity;
  final DeviceStorage _storage;
  final Future<DownloadLimits?> Function() _limits;
  final DateTime Function() _now;

  /// False on a phone that gave the vault no folder.
  final bool canKeep;

  final _changes = StreamController<List<LessonDownload>>.broadcast();
  Map<String, _Record>? _records;
  Future<void>? _running;
  Future<void> _saving = Future.value();

  /// The download being fetched was removed: its fetch stops at the next
  /// file. The record itself, as the lesson may be asked for again meanwhile.
  _Record? _stopped;

  Future<Map<String, _Record>> _load() async {
    if (_records case final records?) return records;
    final saved = await _vault.readJson(_indexName);
    final records = <String, _Record>{};
    for (final item in saved?.readList('lessons') ?? const <Object?>[]) {
      final record = _Record.fromJson(item);
      if (record != null) records[record.lessonId] = record;
    }
    return _records = records;
  }

  /// One write at a time, in the order asked for.
  Future<void> _save() => _saving = _saving.then((_) => _writeIndex());

  Future<void> _writeIndex() async {
    try {
      await _vault.putJson(_indexName, {
        'lessons': [
          for (final record in (_records ?? const {}).values) record.toJson(),
        ],
      });
    } on Object catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'The downloads could not be saved');
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(downloads);
  }

  /// Everything a record still names stays; the rest goes.
  Future<void> _sweep() async {
    final records = (_records ?? const <String, _Record>{}).values;
    await _vault.keepOnly(
      {for (final record in records) ...record.files},
      {
        if (records.isNotEmpty) _indexName,
        for (final record in records) KeptLesson.nameOf(record.lessonId),
      },
    );
  }

  @override
  Future<bool> available() async => canKeep && await _limits() != null;

  @override
  List<LessonDownload> get downloads => [
    for (final record in (_records ?? const <String, _Record>{}).values)
      record.entity,
  ];

  @override
  Stream<List<LessonDownload>> get changes => _changes.stream;

  @override
  bool get wifiOnly => _settings.downloadsWifiOnly;

  @override
  Future<void> setWifiOnly({required bool on}) async {
    await _settings.setDownloadsWifiOnly(on: on);
    // Off: what waited for Wi-Fi may go now.
    if (!on) unawaited(_run());
  }

  @override
  Future<Result<DownloadUsage>> usage() => guard(_usage);

  Future<DownloadUsage> _usage() async {
    final limits = await _limits();
    if (limits == null) throw const FormatException('Downloads are off');
    final records = await _load();
    return DownloadUsage(
      usedBytes: await _vault.usedBytes(),
      maxBytes: limits.maxBytes,
      lessons: _count(records.values, DownloadStatus.done),
      maxLessons: limits.maxLessons,
      freeBytes: await _storage.freeBytes(),
    );
  }

  static int _count(Iterable<_Record> records, DownloadStatus status) =>
      records.where((record) => record.status == status).length;

  /// Why [more] bytes don't fit, or [lessons] kept in all are too many; else
  /// null.
  DownloadProblem? _misfit(
    DownloadUsage usage,
    DownloadLimits limits, {
    required int more,
    required int lessons,
  }) {
    if (lessons > limits.maxLessons) return DownloadProblem.tooManyLessons;
    if (usage.usedBytes + more > limits.maxBytes) {
      return DownloadProblem.overLimit;
    }
    final free = usage.freeBytes;
    if (free != null && free - more < limits.minFreeBytes) {
      return DownloadProblem.noRoom;
    }
    return null;
  }

  int _missing(DownloadManifestModel manifest) => manifest.files
      .where((file) => !_vault.has(file.url))
      .fold(0, (sum, file) => sum + file.bytes);

  @override
  Future<Result<DownloadEstimate>> estimate(List<DownloadRequest> lessons) =>
      guard(() async {
        final limits = await _limits();
        if (limits == null) throw const FormatException('Downloads are off');
        final records = await _load();
        final wanted = [
          for (final lesson in lessons)
            if (!records.containsKey(lesson.lessonId)) lesson,
        ];
        var bytes = 0;
        var count = 0;
        for (final lesson in wanted) {
          try {
            bytes += _missing(await _remote.getManifest(lesson.lessonId));
            count++;
          } catch (error, stackTrace) {
            // A lesson the server doesn't offer is left out of the offer.
            final failure = FailureMapper.fromError(error, stackTrace);
            if (failure is! ForbiddenFailure && failure is! NotFoundFailure) {
              rethrow;
            }
          }
        }
        final usage = await _usage();
        // What is on its way will take its place too.
        final coming = records.values.where((record) => record.active).length;
        return DownloadEstimate(
          lessons: count,
          bytes: bytes,
          usage: usage,
          problem: _misfit(
            usage,
            limits,
            more: bytes,
            lessons: usage.lessons + coming + count,
          ),
        );
      });

  @override
  Future<void> start(List<DownloadRequest> lessons) async {
    final records = await _load();
    for (final lesson in lessons) {
      final kept = records[lesson.lessonId];
      if (kept != null && kept.status != DownloadStatus.failed) continue;
      records[lesson.lessonId] = _Record(
        lessonId: lesson.lessonId,
        title: lesson.title,
        unitTitle: lesson.unitTitle,
        files: kept?.files ?? const [],
      );
    }
    await _save();
    _emit();
    unawaited(_run());
  }

  @override
  Future<void> remove(String lessonId) async {
    final records = await _load();
    final record = records.remove(lessonId);
    if (record == null) return;
    await _save();
    _emit();
    if (record.status == DownloadStatus.downloading) {
      // Its fetch sweeps once it has stopped, so no file lands afterwards.
      _stopped = record;
    } else {
      await _sweep();
    }
  }

  @override
  Future<void> removeAll() async {
    final records = await _load();
    final fetching = records.values
        .where((record) => record.status == DownloadStatus.downloading)
        .firstOrNull;
    records.clear();
    _stopped = fetching;
    await _save();
    _emit();
    await _sweep();
  }

  @override
  Future<void> markDone(Set<String> lessonIds) async {
    final records = await _load();
    var changed = false;
    for (final id in lessonIds) {
      final record = records[id];
      if (record == null || record.doneAt != null) continue;
      record.doneAt = _now();
      changed = true;
    }
    if (changed) await _save();
  }

  @override
  Future<void> tidy() async {
    final records = await _load();
    final limits = await _limits();
    final now = _now();
    final online = await _connectivity.isOnline();
    for (final record in [...records.values]) {
      switch (record.status) {
        // The app closed mid-fetch, or the connection dropped: carry on.
        case DownloadStatus.downloading when _running == null:
          record.status = DownloadStatus.queued;
        case DownloadStatus.failed
            when record.problem == DownloadProblem.network:
          record
            ..status = DownloadStatus.queued
            ..problem = null;
        case DownloadStatus.done:
          final doneAt = record.doneAt;
          final keepFor = limits?.keepDoneFor;
          if (doneAt != null &&
              keepFor != null &&
              now.isAfter(doneAt.add(keepFor))) {
            records.remove(record.lessonId);
          } else if (record.entity.expiredAt(now) && online && limits != null) {
            await _renew(record, limits);
          }
        default:
      }
    }
    await _save();
    _emit();
    await _sweep();
    unawaited(_run());
  }

  /// A download that ran out: the same version opens for another while, a
  /// new one is fetched again, and a lesson no longer offered is removed.
  Future<void> _renew(_Record record, DownloadLimits limits) async {
    try {
      final manifest = await _remote.getManifest(record.lessonId);
      if (manifest.version != record.version) {
        record.status = DownloadStatus.queued;
        return;
      }
      record.expiresAt = _now().add(limits.validFor);
      await _vault.putJson(
        KeptLesson.nameOf(record.lessonId),
        KeptLesson.wrap(
          manifest.lesson,
          version: manifest.version,
          expiresAt: record.expiresAt!,
        ),
      );
    } catch (error, stackTrace) {
      final failure = FailureMapper.fromError(error, stackTrace);
      if (failure is ForbiddenFailure || failure is NotFoundFailure) {
        _records?.remove(record.lessonId);
      }
      // Anything else: it stays run out until the server answers.
    }
  }

  /// Fetches what is queued, one lesson after another. A second call while
  /// it runs joins the first.
  Future<void> _run() => _running ??= () async {
    try {
      final waited = <String>{};
      while (true) {
        final next = (await _load()).values
            .where(
              (record) =>
                  record.status == DownloadStatus.queued &&
                  !waited.contains(record.lessonId),
            )
            .firstOrNull;
        if (next == null) break;
        if (wifiOnly && !await _connectivity.isOnWifi()) {
          next.problem = DownloadProblem.waitingForWifi;
          waited.add(next.lessonId);
          _emit();
          continue;
        }
        await _download(next);
      }
    } finally {
      _running = null;
    }
  }();

  Future<void> _download(_Record record) async {
    record
      ..status = DownloadStatus.downloading
      ..problem = null
      ..received = 0;
    _emit();
    final problem = await _try(record);
    if (_gone(record)) {
      _stopped = null;
      await _sweep();
      return;
    }
    if (problem == null) {
      record
        ..status = DownloadStatus.done
        ..received = record.bytes
        ..savedAt = _now();
    } else {
      record
        ..status = DownloadStatus.failed
        ..problem = problem;
    }
    await _save();
    _emit();
  }

  /// The one place a download's error becomes what the learner is told.
  Future<DownloadProblem?> _try(_Record record) async {
    try {
      await _fetch(record);
      return null;
    } on _Misfit catch (misfit) {
      return misfit.problem;
    } on FormatException catch (error) {
      AppLogger.debug('A lesson could not be kept: $error');
      return DownloadProblem.unsupported;
    } on FileSystemException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'A download could not be written');
      return DownloadProblem.noRoom;
    } catch (error, stackTrace) {
      return switch (FailureMapper.fromError(error, stackTrace)) {
        ForbiddenFailure() || NotFoundFailure() => DownloadProblem.refused,
        _ => DownloadProblem.network,
      };
    }
  }

  bool _gone(_Record record) => identical(_stopped, record);

  Future<void> _fetch(_Record record) async {
    final limits = await _limits();
    if (limits == null) throw const _Misfit(DownloadProblem.refused);
    final manifest = await _remote.getManifest(record.lessonId);
    record
      ..bytes = manifest.bytes
      ..version = manifest.version
      ..files = [for (final file in manifest.files) file.url];
    final usage = await _usage();
    final misfit = _misfit(
      usage,
      limits,
      more: _missing(manifest),
      lessons: usage.lessons + 1,
    );
    if (misfit != null) throw _Misfit(misfit);
    // Its files are named before the first arrives, so a tidy-up after a
    // cut keeps what is half done.
    await _save();

    for (final file in manifest.files) {
      if (_gone(record)) return;
      final before = record.received;
      if (!_vault.has(file.url)) {
        if (file.kind == ManifestFileKind.video) {
          await _keepVideo(record, file);
        } else {
          await _vault.put(
            file.url,
            await _client.fetch(
              Uri.parse(file.url),
              onReceived: (received) => _progress(record, before + received),
            ),
            contentType: file.contentType,
          );
        }
      }
      if (_gone(record)) return;
      record.received = before + file.bytes;
      _emit();
    }
    record.expiresAt = _now().add(limits.validFor);
    // The lesson itself goes last: with it the lesson opens offline.
    await _vault.putJson(
      KeptLesson.nameOf(record.lessonId),
      KeptLesson.wrap(
        manifest.lesson,
        version: manifest.version,
        expiresAt: record.expiresAt!,
      ),
    );
  }

  /// The lightest rendition, a part at a time; parts kept by an earlier try
  /// aren't fetched again.
  Future<void> _keepVideo(_Record record, ManifestFile file) async {
    var address = Uri.parse(file.url);
    var text = utf8.decode(await _client.fetch(address));
    if (HlsPlaylist.isMaster(text)) {
      address = HlsPlaylist.lightest(text, address);
      text = utf8.decode(await _client.fetch(address));
    }
    final media = HlsPlaylist.media(
      text,
      address,
      ivPrefix: await _vault.videoIvPrefix(file.url),
    );
    final before = record.received;
    for (final (index, part) in media.parts.indexed) {
      if (_gone(record)) return;
      if (!_vault.hasVideoPart(file.url, part.name)) {
        await _vault.putVideoPart(
          file.url,
          part,
          await _client.fetch(part.source),
        );
      }
      _progress(
        record,
        before + file.bytes * (index + 1) ~/ media.parts.length,
      );
    }
    await _vault.finishVideo(file.url, media.lines);
  }

  void _progress(_Record record, int received) {
    final capped = record.bytes > 0 && received > record.bytes
        ? record.bytes
        : received;
    if (capped - record.received < _tick && capped < record.bytes) return;
    record.received = capped;
    _emit();
  }
}

/// A download that doesn't fit, with why.
final class _Misfit implements Exception {
  const _Misfit(this.problem);

  final DownloadProblem problem;
}

/// A download as the index keeps it.
final class _Record {
  _Record({
    required this.lessonId,
    required this.title,
    this.unitTitle = '',
    this.status = DownloadStatus.queued,
    this.bytes = 0,
    this.received = 0,
    this.version = 0,
    this.files = const [],
    this.problem,
    this.savedAt,
    this.expiresAt,
    this.doneAt,
  });

  final String lessonId;
  final String title;
  final String unitTitle;
  DownloadStatus status;
  int bytes;
  int received;
  int version;

  /// The addresses of its files, which keep them from being swept.
  List<String> files;
  DownloadProblem? problem;
  DateTime? savedAt;
  DateTime? expiresAt;

  /// When the server was first seen to count the lesson completed.
  DateTime? doneAt;

  bool get active =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  LessonDownload get entity => LessonDownload(
    lessonId: lessonId,
    title: title,
    unitTitle: unitTitle,
    status: status,
    bytes: bytes,
    received: received,
    problem: problem,
    savedAt: savedAt,
    expiresAt: expiresAt,
  );

  Map<String, Object?> toJson() => {
    'lessonId': lessonId,
    'title': title,
    'unitTitle': unitTitle,
    'status': status.name,
    'bytes': bytes,
    'received': received,
    'version': version,
    'files': files,
    'problem': problem?.name,
    'savedAt': savedAt?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'doneAt': doneAt?.toIso8601String(),
  };

  /// A record that can't be read is dropped; its files are swept with it.
  static _Record? fromJson(Object? item) {
    if (item is! Map) return null;
    final json = item.cast<String, Object?>();
    final lessonId = json.readString('lessonId');
    final status = DownloadStatus.values.asNameMap()[json['status']];
    if (lessonId == null || status == null) return null;
    DateTime? time(String key) => DateTime.tryParse('${json[key]}');
    return _Record(
      lessonId: lessonId,
      title: json.readString('title') ?? '',
      unitTitle: json.readString('unitTitle') ?? '',
      status: status,
      bytes: json.readInt('bytes') ?? 0,
      received: json.readInt('received') ?? 0,
      version: json.readInt('version') ?? 0,
      files: [...?json.readList('files')?.whereType<String>()],
      problem: DownloadProblem.values.asNameMap()[json['problem']],
      savedAt: time('savedAt'),
      expiresAt: time('expiresAt'),
      doneAt: time('doneAt'),
    );
  }
}
