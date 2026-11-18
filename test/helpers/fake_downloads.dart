import 'dart:async';
import 'dart:typed_data';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/media/device_storage.dart';
import 'package:englizia/core/media/vault_cipher.dart';
import 'package:englizia/core/network/media_client.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/downloads/domain/entities/lesson_download.dart';
import 'package:englizia/features/downloads/domain/repositories/download_repository.dart';

/// The vault's key, in memory.
class MemoryKeyStore implements VaultKeyStore {
  String? key;

  @override
  Future<String?> read() async => key;

  @override
  Future<void> write(String key) async => this.key = key;

  @override
  Future<void> delete() async => key = null;
}

class FakeDeviceStorage implements DeviceStorage {
  FakeDeviceStorage([this.free]);

  int? free;

  @override
  Future<int?> freeBytes() async => free;
}

/// Serves [files] by address (without its query), records what was asked
/// for, and fails the addresses in [broken] as a dropped connection.
class FakeMediaFiles implements MediaClient {
  FakeMediaFiles(this.files);

  final Map<String, List<int>> files;
  final broken = <String>{};
  final fetched = <String>[];

  /// Completes a fetch only once the test lets it.
  Completer<void>? hold;

  @override
  Future<Uint8List> fetch(
    Uri uri, {
    void Function(int received)? onReceived,
  }) async {
    final address = uri.replace(query: '').toString().replaceAll('?', '');
    fetched.add(address);
    await hold?.future;
    final bytes = files[address];
    if (broken.contains(address) || bytes == null) {
      throw const NetworkException('connectionError');
    }
    onReceived?.call(bytes.length);
    return Uint8List.fromList(bytes);
  }
}

/// Downloads that tests drive by hand.
class FakeDownloadRepository implements DownloadRepository {
  FakeDownloadRepository({this.isAvailable = true});

  bool isAvailable;
  final _changes = StreamController<List<LessonDownload>>.broadcast();
  final kept = <String, LessonDownload>{};
  final started = <List<DownloadRequest>>[];
  final removed = <String>[];
  final done = <String>{};
  var tidied = 0;
  var removedAll = 0;
  bool wifi = true;

  /// What [estimate] answers.
  Result<DownloadEstimate> estimated = const Ok(
    DownloadEstimate(
      lessons: 2,
      bytes: 12 * 1024 * 1024,
      usage: DownloadUsage(
        usedBytes: 0,
        maxBytes: 1024 * 1024 * 1024,
        lessons: 0,
        maxLessons: 40,
        freeBytes: 5 * 1024 * 1024 * 1024,
      ),
    ),
  );

  Result<DownloadUsage> used = const Ok(
    DownloadUsage(
      usedBytes: 120 * 1024 * 1024,
      maxBytes: 1024 * 1024 * 1024,
      lessons: 3,
      maxLessons: 40,
    ),
  );

  /// Puts a download in [status] and tells whoever listens.
  void set(
    String lessonId,
    DownloadStatus status, {
    String title = 'Lesson',
    int bytes = 1000,
    int received = 0,
    DownloadProblem? problem,
  }) {
    kept[lessonId] = LessonDownload(
      lessonId: lessonId,
      title: title,
      unitTitle: 'Unit 1',
      status: status,
      bytes: bytes,
      received: received,
      problem: problem,
    );
    _changes.add(downloads);
  }

  @override
  Future<bool> available() async => isAvailable;

  @override
  List<LessonDownload> get downloads => kept.values.toList();

  @override
  Stream<List<LessonDownload>> get changes => _changes.stream;

  @override
  Future<Result<DownloadEstimate>> estimate(
    List<DownloadRequest> lessons,
  ) async => estimated;

  @override
  Future<void> start(List<DownloadRequest> lessons) async {
    started.add(lessons);
    for (final lesson in lessons) {
      set(lesson.lessonId, DownloadStatus.queued, title: lesson.title);
    }
  }

  @override
  Future<void> remove(String lessonId) async {
    removed.add(lessonId);
    kept.remove(lessonId);
    _changes.add(downloads);
  }

  @override
  Future<void> removeAll() async {
    removedAll++;
    kept.clear();
    _changes.add(downloads);
  }

  @override
  Future<Result<DownloadUsage>> usage() async => used;

  @override
  bool get wifiOnly => wifi;

  @override
  Future<void> setWifiOnly({required bool on}) async => wifi = on;

  @override
  Future<void> markDone(Set<String> lessonIds) async => done.addAll(lessonIds);

  @override
  Future<void> tidy() async => tidied++;

  Future<void> dispose() => _changes.close();
}

const networkDown = NetworkFailure();
