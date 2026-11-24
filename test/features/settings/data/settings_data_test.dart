import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:englizia/features/settings/data/models/effective_settings_model.dart';
import 'package:englizia/features/settings/data/models/support_links_model.dart';
import 'package:englizia/features/settings/data/models/version_policy_model.dart';
import 'package:englizia/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:englizia/features/settings/domain/entities/app_version.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/entities/support_links.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_settings_repository.dart';

/// The contract's example response: the same file mock mode serves.
final exampleBody =
    jsonDecode(File(SettingsFakeDataSource.asset).readAsStringSync())
        as Map<String, Object?>;

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

/// Fails the first [failures] reads, then serves the example.
class _FlakyDataSource implements SettingsRemoteDataSource {
  _FlakyDataSource({this.failures = 0});

  int failures;
  var calls = 0;

  @override
  Future<EffectiveSettingsModel> getSettings() async {
    calls++;
    if (failures-- > 0) throw const NetworkException('connectionError');
    return EffectiveSettingsModel.fromJson(example());
  }

  /// The dev server's real answer (`test/fixtures/api`).
  @override
  Future<Map<String, Object?>> getSystemConfig() async {
    calls++;
    if (failures-- > 0) throw const NetworkException('connectionError');
    return asJsonMap(ApiClient.unwrap(apiFixture('app_system_config')));
  }
}

Map<String, Object?> example() =>
    asJsonMap(ApiClient.unwrap(jsonDecode(jsonEncode(exampleBody))));

void main() {
  test('the example response parses', () {
    expect(EffectiveSettingsModel.fromJson(example()).entity, testSettings);
  });

  test('the goal fills the reminder body', () {
    expect(
      testSettings.reminder.bodyIn('ar', goalMinutes: 15),
      '15 دقائق فقط وتحافظ على أيامك المتتالية',
    );
    expect(testSettings.reminder.defaultPreset.time, const ReminderTime(20, 0));
    expect(testSettings.dailyGoal.defaultOption.minutes, 10);
  });

  test('unknown slots and malformed times are skipped', () {
    final json = example();
    final notifications = json.readMap('notifications')!;
    notifications['reminderTimes'] = [
      {'slot': 'midnight', 'time': '00:00'},
      {'slot': 'morning', 'time': '25:00'},
      {'slot': 'noon', 'time': '12:30'},
    ];
    notifications['defaultReminderSlot'] = 'evening';
    final reminder = EffectiveSettingsModel.fromJson(json).entity.reminder;
    expect(reminder.presets, const [
      ReminderPreset(slot: ReminderSlot.noon, time: ReminderTime(12, 30)),
    ]);
    // The default falls back to an offered time.
    expect(reminder.defaultPreset.slot, ReminderSlot.noon);
  });

  test('goal options are sorted, bad ones skipped, the default may be off '
      'the list', () {
    final json = example();
    json.readMap('motivation')!
      ..['dailyGoalOptions'] = [
        {
          'minutes': 20,
          'label': {'ar': 'مكثّف'},
        },
        {'minutes': 0, 'label': 'zero'},
        {'minutes': 7},
        {
          'minutes': 5,
          'label': {'ar': 'مريح'},
        },
      ]
      ..['defaultDailyGoal'] = 12;
    final goal = EffectiveSettingsModel.fromJson(json).entity.dailyGoal;
    expect([for (final o in goal.options) o.minutes], [5, 20]);
    expect(goal.defaultOption.minutes, 5);
  });

  test('challenge options are sorted and bad ones skipped', () {
    final json = example();
    json.readMap('motivation')!
      ..['challengeOptions'] = [
        {
          'days': 30,
          'label': {'ar': 'مذهل'},
        },
        {'days': -1, 'label': 'x'},
        {
          'days': 7,
          'label': {'ar': 'جيد'},
        },
      ]
      ..['defaultChallenge'] = 14;
    final challenge = EffectiveSettingsModel.fromJson(json).entity.challenge;
    expect([for (final o in challenge.options) o.days], [7, 30]);
    expect(challenge.defaultOption.days, 7);
  });

  test('the challenge needs its question', () {
    final json = example();
    json.readMap('motivation')!.remove('challengeQuestion');
    expect(
      () => EffectiveSettingsModel.fromJson(json).entity,
      throwsFormatException,
    );
  });

  test('the lesson length is optional', () {
    final json = example();
    json.readMap('motivation')!.remove('averageLessonMinutes');
    expect(
      EffectiveSettingsModel.fromJson(json).entity.dailyGoal.lessonMinutes,
      isNull,
    );
  });

  test('the limits for downloads, every one from the panel', () {
    expect(
      EffectiveSettingsModel.fromJson(example()).entity.downloads,
      const DownloadLimits(
        maxBytes: 1024 * 1024 * 1024,
        maxLessons: 40,
        validFor: Duration(days: 30),
        minFreeBytes: 300 * 1024 * 1024,
        keepDoneFor: Duration(days: 14),
      ),
    );
  });

  test('downloads are off unless the panel gives every limit', () {
    DownloadLimits? limits(Map<String, Object?>? downloads) =>
        EffectiveSettingsModel.fromJson({
          ...example(),
          'downloads': downloads,
        }).entity.downloads;
    const whole = {
      'enabled': true,
      'maxMegabytes': 10,
      'maxLessons': 2,
      'validDays': 7,
      'minFreeMegabytes': 0,
    };

    expect(limits(null), isNull);
    expect(limits({...whole, 'enabled': false}), isNull);
    expect(limits({...whole}..remove('validDays')), isNull);
    expect(limits({...whole, 'maxLessons': 0}), isNull);
    // No while for completed lessons: they are kept.
    expect(limits(whole)?.keepDoneFor, isNull);
    expect(limits(whole)?.minFreeBytes, 0);
  });

  test('incomplete settings are rejected', () {
    expect(
      () => EffectiveSettingsModel.fromJson(
        example()..remove('motivation'),
      ).entity,
      throwsFormatException,
    );
    expect(
      () => EffectiveSettingsModel.fromJson(
        example()..remove('notifications'),
      ).entity,
      throwsFormatException,
    );
    expect(
      () => EffectiveSettingsModel.fromJson(const {}).entity,
      throwsFormatException,
    );
  });

  test('GET /api/v1/app/settings', () async {
    final adapter = FakeHttpAdapter(
      (_) => FakeResponse(200, body: exampleBody),
    );
    final client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

    final settings = await SettingsRemoteDataSourceImpl(client).getSettings();

    expect(adapter.requests.single.path, '/api/v1/app/settings');
    expect(settings.entity, testSettings);
  });

  group('while the server has no settings', () {
    late Map<String, FakeResponse> answers;
    late FakeHttpAdapter adapter;

    SettingsRemoteDataSourceImpl source({bool bundled = true}) {
      adapter = FakeHttpAdapter(
        (request) => answers[request.path] ?? const FakeResponse(500, body: {}),
      );
      return SettingsRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
        bundled: bundled ? _DiskBundle() : null,
      );
    }

    const missing = FakeResponse(
      404,
      body: {
        'statusCode': 404,
        'error': {'code': 'route.not_found'},
      },
    );

    setUp(() {
      answers = {
        '/api/v1/app/settings': missing,
        '/api/v1/app/system/config': FakeResponse(
          200,
          body: jsonDecode(
            File('test/fixtures/api/app_system_config.json').readAsStringSync(),
          ),
        ),
      };
    });

    test('onboarding reads the bundled ones', () async {
      final settings = await source().getSettings();

      expect(settings.entity.challenge, testSettings.challenge);
      expect(settings.entity.reminder, testSettings.reminder);
      expect(settings.entity.dailyGoal.defaultMinutes, 10);
    });

    test('their goals are those system/config offers', () async {
      answers['/api/v1/app/system/config'] = const FakeResponse(
        200,
        body: {
          'statusCode': 200,
          'data': {
            'dailyGoalOptions': [
              {'minutes': 10, 'xp': 40},
              {'minutes': 20, 'xp': 80},
            ],
          },
        },
      );

      final goals = (await source().getSettings()).entity.dailyGoal.options;

      expect(goals.map((g) => g.minutes), [10, 20]);
    });

    test('another failure is still one', () async {
      answers['/api/v1/app/settings'] = const FakeResponse(500, body: {});

      await expectLater(source().getSettings(), throwsA(isA<ApiException>()));
    });

    test('with nothing bundled, the server\u2019s answer stands', () async {
      await expectLater(
        source(bundled: false).getSettings(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  test('mock mode serves the bundled example', () async {
    final settings = await SettingsFakeDataSource(
      _DiskBundle(),
      latency: Duration.zero,
    ).getSettings();
    expect(settings.entity, testSettings);
  });

  group('SettingsRepositoryImpl', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('maps errors through the error funnel and retries them', () async {
      final source = _FlakyDataSource(failures: 1);
      final repository = SettingsRepositoryImpl(
        source,
        SettingsStorageService(prefs),
      );

      final first = await repository.getSettings();
      expect((first as Err).failure, isA<NetworkFailure>());

      expect(await repository.getSettings(), const Ok(testSettings));
      expect(source.calls, 2);
    });

    test('keeps a success for the session', () async {
      final source = _FlakyDataSource();
      final repository = SettingsRepositoryImpl(
        source,
        SettingsStorageService(prefs),
      );

      await repository.getSettings();
      await repository.getSettings();

      expect(source.calls, 1);
    });
  });

  group('versions', () {
    test("the server's system config: its minimum and its latest", () {
      final config = asJsonMap(
        ApiClient.unwrap(apiFixture('app_system_config')),
      );
      expect(
        VersionPolicyModel.fromJson(config).entity,
        const VersionPolicy(
          minimum: AppVersion(0, 1),
          recommended: AppVersion(0, 1),
        ),
      );
    });

    test('the mock\'s, with a store page and a newer version', () {
      final config = asJsonMap(
        ApiClient.unwrap(
          jsonDecode(
            File(SettingsFakeDataSource.configAsset).readAsStringSync(),
          ),
        ),
      );
      expect(
        VersionPolicyModel.fromJson(config).entity,
        VersionPolicy(
          minimum: const AppVersion(0, 1),
          recommended: const AppVersion(0, 1, 1),
          updateUrl: Uri.parse(
            'https://play.google.com/store/apps/details?id=com.engleazia.app',
          ),
        ),
      );
    });

    test("a value that isn't valid is left out alone", () {
      expect(
        VersionPolicyModel.fromJson({
          'minSupportedVersion': '1.x',
          'latestVersion': '2.1',
          'storeUrl': 'market://details?id=x',
        }).entity,
        const VersionPolicy(recommended: AppVersion(2, 1)),
      );
    });

    test('kept in the shape it came in', () {
      final policy = VersionPolicy(
        minimum: const AppVersion(1, 2),
        recommended: const AppVersion(1, 3),
        updateUrl: Uri.parse('https://example.com/app'),
      );
      expect(
        VersionPolicyModel.fromJson(VersionPolicyModel(policy).toJson()).entity,
        policy,
      );
    });
  });

  group('SettingsRepositoryImpl versions', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    SettingsRepositoryImpl repository(SettingsRemoteDataSource source) =>
        SettingsRepositoryImpl(source, SettingsStorageService(prefs));

    test(
      'kept on the phone, and served from there without a connection',
      () async {
        expect(
          ((await repository(_FlakyDataSource()).getVersionPolicy())
                  as Ok<VersionPolicy>)
              .value
              .minimum,
          const AppVersion(0, 1),
        );

        final offline = await repository(
          _FlakyDataSource(failures: 1),
        ).getVersionPolicy();
        expect(
          (offline as Ok<VersionPolicy>).value.minimum,
          const AppVersion(0, 1),
        );
      },
    );

    test('an error with no connection and nothing kept', () async {
      final result = await repository(
        _FlakyDataSource(failures: 1),
      ).getVersionPolicy();
      expect((result as Err).failure, isA<NetworkFailure>());
    });
  });

  group('support links', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('the dev server has none yet', () async {
      final result = await SettingsRepositoryImpl(
        _FlakyDataSource(),
        SettingsStorageService(prefs),
      ).getSupportLinks();
      expect((result as Ok<SupportLinks>).value, SupportLinks.none);
    });

    test('the number and https pages; anything else is left out', () {
      expect(
        SupportLinksModel.fromJson(const {
          'supportWhatsapp': '+963 900 000 000',
          'privacyUrl': 'https://example.com/privacy',
          'termsUrl': 'http://example.com/terms',
        }),
        SupportLinks(
          whatsapp: '+963 900 000 000',
          privacy: Uri.parse('https://example.com/privacy'),
        ),
      );
    });

    test('one system config a session, the versions included', () async {
      final source = _FlakyDataSource();
      final repository = SettingsRepositoryImpl(
        source,
        SettingsStorageService(prefs),
      );
      await repository.getVersionPolicy();
      await repository.getSupportLinks();
      await repository.getSupportLinks();
      expect(source.calls, 1);
    });
  });
}
