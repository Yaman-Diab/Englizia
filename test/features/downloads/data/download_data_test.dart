import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/media/kept_lesson.dart';
import 'package:englizia/core/media/media_vault.dart';
import 'package:englizia/core/media/vault_cipher.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/downloads/data/datasources/download_remote_data_source.dart';
import 'package:englizia/features/downloads/data/models/download_manifest_model.dart';
import 'package:englizia/features/downloads/data/repositories/download_repository_impl.dart';
import 'package:englizia/features/downloads/domain/entities/lesson_download.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_downloads.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';

const _cdn = 'https://cdn.example.com';
const _picture = '$_cdn/p1.webp';
const _clip = '$_cdn/c1.mp3';
const _video = '$_cdn/v1/index.m3u8';

const _playlist = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
#EXTINF:6.0,
s0.ts
#EXTINF:6.0,
s1.ts
#EXT-X-ENDLIST
''';

const _limits = DownloadLimits(
  maxBytes: 10000,
  maxLessons: 3,
  validFor: Duration(days: 30),
  minFreeBytes: 1000,
  keepDoneFor: Duration(days: 14),
);

Map<String, Object?> _manifest(
  String lessonId, {
  int version = 1,
  List<Map<String, Object?>>? files,
}) => {
  'lessonId': lessonId,
  'lessonVersion': version,
  'lesson': {'id': lessonId, 'version': version, 'exercises': <Object?>[]},
  'files':
      files ??
      [
        {
          'url': '$_picture?sig=1',
          'kind': 'picture',
          'bytes': 100,
          'contentType': 'image/webp',
        },
        {'url': _clip, 'kind': 'clip', 'bytes': 200},
        {'url': _video, 'kind': 'video', 'bytes': 600},
      ],
};

class _Remote implements DownloadRemoteDataSource {
  final manifests = <String, Map<String, Object?>>{};
  final refused = <String, int>{};
  final asked = <String>[];

  @override
  Future<DownloadManifestModel> getManifest(String lessonId) async {
    asked.add(lessonId);
    if (refused[lessonId] case final status?) {
      throw ApiException(statusCode: status);
    }
    return DownloadManifestModel.fromJson(manifests[lessonId]!);
  }
}

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  late Directory root;
  late FileMediaVault vault;
  late FakeMediaFiles files;
  late _Remote remote;
  late FakeConnectivityService connectivity;
  late FakeDeviceStorage storage;
  late SettingsStorageService settings;
  late DateTime now;

  const first = DownloadRequest(lessonId: 'l1', title: 'Hello', unitTitle: 'U');
  const second = DownloadRequest(lessonId: 'l2', title: 'Colors');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStorageService(await SharedPreferences.getInstance());
    root = Directory.systemTemp.createTempSync('downloads_test_');
    vault = FileMediaVault(root: root, cipher: VaultCipher(MemoryKeyStore()));
    files = FakeMediaFiles({
      _picture: List.filled(100, 1),
      _clip: List.filled(200, 2),
      _video: utf8.encode(_playlist),
      '$_cdn/v1/s0.ts': List.filled(300, 3),
      '$_cdn/v1/s1.ts': List.filled(300, 4),
      '$_cdn/p2.webp': List.filled(50, 5),
    });
    remote = _Remote()
      ..manifests['l1'] = _manifest('l1')
      ..manifests['l2'] = _manifest(
        'l2',
        files: [
          {'url': '$_picture?sig=2', 'kind': 'picture', 'bytes': 100},
          {'url': '$_cdn/p2.webp', 'kind': 'picture', 'bytes': 50},
        ],
      );
    connectivity = FakeConnectivityService();
    storage = FakeDeviceStorage(1000000);
    now = DateTime.utc(2026, 11, 18, 10);
  });

  tearDown(() async {
    await vault.clear();
    await connectivity.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  DownloadRepositoryImpl repository({DownloadLimits? limits = _limits}) =>
      DownloadRepositoryImpl(
        remote,
        client: files,
        vault: vault,
        settings: settings,
        connectivity: connectivity,
        storage: storage,
        limits: () async => limits,
        now: () => now,
      );

  /// Runs [act] and waits until nothing is on its way any more.
  Future<void> settle(
    DownloadRepositoryImpl subject,
    Future<void> Function() act,
  ) async {
    final idle = subject.changes.firstWhere(
      (all) => all.every(
        (download) =>
            !download.active ||
            download.problem == DownloadProblem.waitingForWifi,
      ),
    );
    await act();
    await idle.timeout(const Duration(seconds: 10));
  }

  LessonDownload of(DownloadRepositoryImpl subject, String lessonId) =>
      subject.downloads.firstWhere((d) => d.lessonId == lessonId);

  group('the manifest', () {
    test('the example parses; an unknown file is left out', () {
      final body = jsonDecode(
        File(DownloadFakeDataSource.asset).readAsStringSync(),
      );
      final manifest = DownloadManifestModel.fromJson(
        asJsonMap(ApiClient.unwrap(body)),
      );
      expect(manifest.version, 3);
      expect(manifest.files.map((f) => f.kind), [
        ManifestFileKind.picture,
        ManifestFileKind.clip,
        ManifestFileKind.video,
      ]);
      expect(manifest.bytes, 900000);

      final odd = DownloadManifestModel.fromJson(
        _manifest(
          'l',
          files: [
            {'url': _picture, 'kind': 'hologram', 'bytes': 1},
            {'kind': 'picture', 'bytes': 1},
            {'url': _clip, 'kind': 'clip', 'bytes': -5},
          ],
        ),
      );
      expect(odd.files.single.bytes, 0);
      expect(
        () => DownloadManifestModel.fromJson(const {'lessonId': 'l'}),
        throwsFormatException,
      );
    });

    test('GET /api/v1/app/lessons/{id}/download', () async {
      final adapter = FakeHttpAdapter(
        (_) => FakeResponse(
          200,
          body: {'statusCode': 200, 'data': _manifest('l1'), 'error': null},
        ),
      );
      final manifest = await DownloadRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      ).getManifest('l1');

      expect(adapter.requests.single.path, '/api/v1/app/lessons/l1/download');
      expect(manifest.lessonId, 'l1');
    });

    test('mock mode serves the example for any lesson', () async {
      final manifest = await DownloadFakeDataSource(
        _DiskBundle(),
        latency: Duration.zero,
      ).getManifest('any');
      expect(manifest.lessonId, 'any');
    });
  });

  group('keeping a lesson', () {
    test('its files sealed, the lesson last, then it opens offline', () async {
      final subject = repository();
      final seen = <double?>[];
      final listening = subject.changes.listen(
        (all) => seen.add(all.firstOrNull?.progress),
      );
      await settle(subject, () => subject.start([first]));
      await listening.cancel();

      final download = of(subject, 'l1');
      expect(download.status, DownloadStatus.done);
      expect(download.title, 'Hello');
      expect((download.bytes, download.received), (900, 900));
      expect(download.savedAt, now);
      expect(download.expiresAt, now.add(const Duration(days: 30)));
      expect(seen.last, 1);
      expect(seen.whereType<double>().any((p) => p > 0 && p < 1), isTrue);

      expect(vault.has(_picture), isTrue);
      expect(await vault.read(_clip), List.filled(200, 2));
      expect(await vault.playable(_video), isNotNull);
      final lesson = KeptLesson.lessonOf(
        await vault.readJson(KeptLesson.nameOf('l1')),
        now,
      );
      expect(lesson?['id'], 'l1');
    });

    test('a cut connection keeps what arrived; the next try fetches the '
        'rest only', () async {
      final subject = repository();
      files.broken.add('$_cdn/v1/s1.ts');
      await settle(subject, () => subject.start([first]));

      final cut = of(subject, 'l1');
      expect(
        (cut.status, cut.problem),
        (DownloadStatus.failed, DownloadProblem.network),
      );
      expect(vault.has(_picture), isTrue);
      expect(vault.has(_video), isFalse);
      expect(vault.hasVideoPart(_video, 's0'), isTrue);
      expect(vault.hasJson(KeptLesson.nameOf('l1')), isFalse);

      files.broken.clear();
      files.fetched.clear();
      await settle(subject, () => subject.start([first]));

      expect(of(subject, 'l1').status, DownloadStatus.done);
      expect(files.fetched, [_video, '$_cdn/v1/s1.ts']);
    });

    test('a file two lessons share is fetched once and stays while either '
        'needs it', () async {
      final subject = repository();
      await settle(subject, () => subject.start([first, second]));

      expect(files.fetched.where((a) => a == _picture), hasLength(1));
      expect(subject.downloads.map((d) => d.status), [
        DownloadStatus.done,
        DownloadStatus.done,
      ]);

      await subject.remove('l1');
      expect(vault.has(_picture), isTrue);
      expect(vault.has(_clip), isFalse);
      expect(vault.has(_video), isFalse);
      expect(vault.hasJson(KeptLesson.nameOf('l1')), isFalse);

      await subject.remove('l2');
      expect(vault.has(_picture), isFalse);
      expect(await vault.usedBytes(), 0);
    });

    test('a lesson the server does not offer', () async {
      remote.refused['l1'] = 403;
      final subject = repository();
      await settle(subject, () => subject.start([first]));
      expect(of(subject, 'l1').problem, DownloadProblem.refused);
    });

    test('a video the phone cannot keep', () async {
      files.files[_video] = utf8.encode(
        _playlist.replaceFirst('#EXT-X-ENDLIST', ''),
      );
      final subject = repository();
      await settle(subject, () => subject.start([first]));
      expect(of(subject, 'l1').problem, DownloadProblem.unsupported);
    });

    test('the index is the vault\'s: another start reads it', () async {
      final subject = repository();
      await settle(subject, () => subject.start([first]));

      final again = repository();
      await again.tidy();
      expect(of(again, 'l1').status, DownloadStatus.done);
      expect(of(again, 'l1').title, 'Hello');
    });
  });

  group('the limits', () {
    test('the panel\'s room', () async {
      final subject = repository(
        limits: const DownloadLimits(
          maxBytes: 500,
          maxLessons: 3,
          validFor: Duration(days: 30),
          minFreeBytes: 0,
        ),
      );
      await settle(subject, () => subject.start([first]));
      expect(of(subject, 'l1').problem, DownloadProblem.overLimit);
      expect(files.fetched, isEmpty);
    });

    test('the panel\'s count of lessons', () async {
      final subject = repository(
        limits: const DownloadLimits(
          maxBytes: 10000,
          maxLessons: 1,
          validFor: Duration(days: 30),
          minFreeBytes: 0,
        ),
      );
      await settle(subject, () => subject.start([first, second]));
      expect(of(subject, 'l1').status, DownloadStatus.done);
      expect(of(subject, 'l2').problem, DownloadProblem.tooManyLessons);
    });

    test('the phone\'s own room', () async {
      storage.free = 1500;
      final subject = repository();
      await settle(subject, () => subject.start([first]));
      expect(of(subject, 'l1').problem, DownloadProblem.noRoom);
    });

    test('off in the panel: nothing is offered', () async {
      expect(await repository(limits: null).available(), isFalse);
      expect(await repository().available(), isTrue);
      expect(await repository(limits: null).usage(), isA<Err<DownloadUsage>>());
    });

    test('an estimate: what is missing, without what is refused', () async {
      remote
        ..manifests['l3'] = _manifest('l3')
        ..refused['l3'] = 404;
      final subject = repository();
      final estimate =
          (await subject.estimate([
                    first,
                    second,
                    const DownloadRequest(lessonId: 'l3', title: 'x'),
                  ])
                  as Ok<DownloadEstimate>)
              .value;

      expect(estimate.lessons, 2);
      // The shared picture is counted for both until one has it.
      expect(estimate.bytes, 900 + 150);
      expect(estimate.problem, isNull);
      expect(estimate.usage.freeBytes, 1000000);

      storage.free = 100;
      final tight = (await subject.estimate([first]) as Ok).value;
      expect((tight as DownloadEstimate).problem, DownloadProblem.noRoom);
    });
  });

  group('Wi-Fi only', () {
    test('on mobile data a lesson waits; turned off, it goes', () async {
      connectivity.wifi = false;
      final subject = repository();
      expect(subject.wifiOnly, isTrue);

      await settle(subject, () => subject.start([first]));
      final waiting = of(subject, 'l1');
      expect(
        (waiting.status, waiting.problem),
        (DownloadStatus.queued, DownloadProblem.waitingForWifi),
      );
      expect(files.fetched, isEmpty);

      await settle(subject, () => subject.setWifiOnly(on: false));
      expect(of(subject, 'l1').status, DownloadStatus.done);
      expect(settings.downloadsWifiOnly, isFalse);
    });
  });

  group('removing', () {
    test('everything', () async {
      final subject = repository();
      await settle(subject, () => subject.start([first, second]));
      await subject.removeAll();

      expect(subject.downloads, isEmpty);
      expect(await vault.usedBytes(), 0);
      final usage = (await subject.usage() as Ok<DownloadUsage>).value;
      expect((usage.usedBytes, usage.lessons, usage.maxLessons), (0, 0, 3));
    });

    test('while it is being fetched: it stops and leaves nothing', () async {
      final subject = repository();
      files.hold = Completer();
      await subject.start([first]);
      await subject.changes.firstWhere(
        (all) => all.firstOrNull?.status == DownloadStatus.downloading,
      );

      await subject.remove('l1');
      expect(subject.downloads, isEmpty);
      files.hold!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(await vault.usedBytes(), 0);
      expect(subject.downloads, isEmpty);
    });
  });

  group('tidying up', () {
    Future<DownloadRepositoryImpl> kept() async {
      final subject = repository();
      await settle(subject, () => subject.start([first]));
      return subject;
    }

    test('run out, same version: it opens for another while', () async {
      final subject = await kept();
      now = now.add(const Duration(days: 31));
      expect(of(subject, 'l1').expiredAt(now), isTrue);
      expect(
        KeptLesson.lessonOf(await vault.readJson(KeptLesson.nameOf('l1')), now),
        isNull,
      );

      files.fetched.clear();
      await subject.tidy();

      expect(of(subject, 'l1').expiresAt, now.add(const Duration(days: 30)));
      expect(files.fetched, isEmpty);
      expect(
        KeptLesson.lessonOf(await vault.readJson(KeptLesson.nameOf('l1')), now),
        isNotNull,
      );
    });

    test('run out, with no connection: it waits as it is', () async {
      final subject = await kept();
      now = now.add(const Duration(days: 31));
      connectivity.online = false;
      remote.asked.clear();

      await subject.tidy();

      expect(remote.asked, isEmpty);
      expect(of(subject, 'l1').expiredAt(now), isTrue);
      expect(vault.has(_picture), isTrue);
    });

    test('run out, a new version: it is fetched again', () async {
      final subject = await kept();
      now = now.add(const Duration(days: 31));
      remote.manifests['l1'] = _manifest(
        'l1',
        version: 2,
        files: [
          {'url': '$_cdn/p2.webp', 'kind': 'picture', 'bytes': 50},
        ],
      );

      await settle(subject, subject.tidy);

      expect(of(subject, 'l1').status, DownloadStatus.done);
      final document = await vault.readJson(KeptLesson.nameOf('l1'));
      expect(document?['version'], 2);
      // The old version's files went with it.
      await subject.tidy();
      expect(vault.has(_clip), isFalse);
      expect(vault.has('$_cdn/p2.webp'), isTrue);
    });

    test('run out, no longer offered: it is removed', () async {
      final subject = await kept();
      now = now.add(const Duration(days: 31));
      remote.refused['l1'] = 404;

      await subject.tidy();

      expect(subject.downloads, isEmpty);
      expect(await vault.usedBytes(), 0);
    });

    test('a completed lesson makes room after the panel\'s while', () async {
      final subject = await kept();
      await subject.markDone({'l1', 'unknown'});

      now = now.add(const Duration(days: 13));
      await subject.tidy();
      expect(subject.downloads, hasLength(1));

      now = now.add(const Duration(days: 2));
      await subject.tidy();
      expect(subject.downloads, isEmpty);
    });

    test('a fetch the app closed on carries on at the next start', () async {
      final closed = repository();
      files.hold = Completer();
      await closed.start([first]);
      await closed.changes.firstWhere(
        (all) => all.firstOrNull?.status == DownloadStatus.downloading,
      );
      // Its files are named in the index from the manifest on.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reopened = repository();
      final hold = files.hold!;
      files.hold = null;
      await settle(reopened, reopened.tidy);
      hold.complete();
      // The first one finishes its file before the folder goes.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(of(reopened, 'l1').status, DownloadStatus.done);
    });

    test('a cut download is tried again', () async {
      final subject = repository();
      files.broken.add(_clip);
      await settle(subject, () => subject.start([first]));
      expect(of(subject, 'l1').status, DownloadStatus.failed);

      files.broken.clear();
      await settle(subject, subject.tidy);
      expect(of(subject, 'l1').status, DownloadStatus.done);
    });
  });
}
