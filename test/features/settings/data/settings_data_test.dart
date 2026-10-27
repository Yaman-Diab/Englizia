import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:englizia/features/settings/data/models/effective_settings_model.dart';
import 'package:englizia/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(() => EffectiveSettingsModel.fromJson(json), throwsFormatException);
  });

  test('the lesson length is optional', () {
    final json = example();
    json.readMap('motivation')!.remove('averageLessonMinutes');
    expect(
      EffectiveSettingsModel.fromJson(json).entity.dailyGoal.lessonMinutes,
      isNull,
    );
  });

  test('incomplete settings are rejected', () {
    expect(
      () => EffectiveSettingsModel.fromJson(example()..remove('motivation')),
      throwsFormatException,
    );
    expect(
      () => EffectiveSettingsModel.fromJson(example()..remove('notifications')),
      throwsFormatException,
    );
    expect(
      () => EffectiveSettingsModel.fromJson(const {}),
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

  test('mock mode serves the bundled example', () async {
    final settings = await SettingsFakeDataSource(
      _DiskBundle(),
      latency: Duration.zero,
    ).getSettings();
    expect(settings.entity, testSettings);
  });

  group('SettingsRepositoryImpl', () {
    test('maps errors through the error funnel and retries them', () async {
      final source = _FlakyDataSource(failures: 1);
      final repository = SettingsRepositoryImpl(source);

      final first = await repository.getSettings();
      expect((first as Err).failure, isA<NetworkFailure>());

      expect(await repository.getSettings(), const Ok(testSettings));
      expect(source.calls, 2);
    });

    test('keeps a success for the session', () async {
      final source = _FlakyDataSource();
      final repository = SettingsRepositoryImpl(source);

      await repository.getSettings();
      await repository.getSettings();

      expect(source.calls, 1);
    });
  });
}
