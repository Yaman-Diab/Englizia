import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/media/kept_lesson.dart';
import 'package:englizia/core/media/media_vault.dart';
import 'package:englizia/core/media/vault_cipher.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/repositories/lesson_repository_impl.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_downloads.dart';

/// No connection: every call fails as the network does.
class _Offline implements LessonRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const NetworkException('connectionError');
}

/// A downloaded lesson (ADR 22) opens with no connection, until it runs out.
void main() {
  late Directory root;
  late FileMediaVault vault;
  late SettingsStorageService settings;
  var now = DateTime.utc(2026, 11, 18);

  final lesson = asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(LessonFakeDataSource.asset).readAsStringSync()),
    ),
  );
  final lessonId = lesson['id']! as String;

  setUp(() async {
    now = DateTime.utc(2026, 11, 18);
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStorageService(await SharedPreferences.getInstance());
    root = Directory.systemTemp.createTempSync('kept_lesson_test_');
    vault = FileMediaVault(root: root, cipher: VaultCipher(MemoryKeyStore()));
  });

  tearDown(() async {
    await vault.clear();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  LessonRepositoryImpl repository() => LessonRepositoryImpl(
    _Offline(),
    settings: settings,
    vault: vault,
    now: () => now,
  );

  Future<void> download({int days = 30}) => vault.putJson(
    KeptLesson.nameOf(lessonId),
    KeptLesson.wrap(
      lesson,
      version: 1,
      expiresAt: DateTime.utc(2026, 11, 18).add(Duration(days: days)),
    ),
  );

  test('not downloaded, no connection: the failure stands', () async {
    final result = await repository().getLesson(lessonId);
    expect((result as Err).failure, isA<NetworkFailure>());
    expect(repository().onPhone(lessonId).kept, isFalse);
  });

  test('downloaded: it opens with no connection, and says so', () async {
    await download();
    final result = await repository().getLesson(lessonId);

    expect((result as Ok<Lesson>).value.id, lessonId);
    expect(repository().onPhone(lessonId).kept, isTrue);
  });

  test('run out: the server has to be asked first', () async {
    await download();
    now = now.add(const Duration(days: 31));
    final result = await repository().getLesson(lessonId);
    expect((result as Err).failure, isA<NetworkFailure>());
  });

  test('a document that is not a lesson is not opened', () async {
    await vault.putJson(KeptLesson.nameOf(lessonId), {'lesson': 'nope'});
    expect(await repository().getLesson(lessonId), isA<Err<Lesson>>());
    expect(KeptLesson.lessonOf(null, now), isNull);
  });

  test('a video plays from the source kept on the phone, whatever the '
      'quality chosen', () async {
    const video = LessonVideo(
      id: 'v',
      duration: Duration(minutes: 1),
      sources: [
        VideoSource(
          quality: VideoQuality.high,
          url: 'https://c.example/h.m3u8',
        ),
        VideoSource(quality: VideoQuality.low, url: 'https://c.example/l.m3u8'),
      ],
    );
    final subject = repository();
    expect(
      subject.videoUrl(video, VideoQuality.high),
      'https://c.example/h.m3u8',
    );

    await vault.finishVideo('https://c.example/l.m3u8', const ['#EXTM3U']);
    expect(
      subject.videoUrl(video, VideoQuality.high),
      'https://c.example/l.m3u8',
    );
  });
}
