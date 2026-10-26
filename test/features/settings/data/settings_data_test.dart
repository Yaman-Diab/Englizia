import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/notifications/data/datasources/reminder_settings_remote_data_source.dart';
import 'package:englizia/features/notifications/data/models/reminder_settings_model.dart';
import 'package:englizia/features/notifications/data/repositories/reminder_settings_repository_impl.dart';
import 'package:englizia/features/notifications/domain/entities/reminder_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';

/// The contract's example response: the same file mock mode serves.
final exampleBody =
    jsonDecode(File(ReminderSettingsFakeDataSource.asset).readAsStringSync())
        as Map<String, Object?>;

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _FailingDataSource implements ReminderSettingsRemoteDataSource {
  @override
  Future<ReminderSettingsModel> getReminderSettings() async =>
      throw const NetworkException('connectionError');
}

void main() {
  const expected = ReminderSettings(
    presets: [
      ReminderPreset(slot: ReminderSlot.morning, time: ReminderTime(8, 0)),
      ReminderPreset(slot: ReminderSlot.noon, time: ReminderTime(13, 0)),
      ReminderPreset(slot: ReminderSlot.evening, time: ReminderTime(20, 0)),
    ],
    defaultSlot: ReminderSlot.evening,
    title: LocalizedText(
      ar: 'حان وقت درسك اليومي',
      en: 'Time for your daily lesson',
    ),
    body: LocalizedText(
      ar: '{minutes} دقائق فقط وتحافظ على أيامك المتتالية',
      en: 'Just {minutes} minutes keeps your streak going',
    ),
    dailyGoalMinutes: 10,
  );

  Map<String, Object?> example() =>
      asJsonMap(ApiClient.unwrap(jsonDecode(jsonEncode(exampleBody))));

  test('the example response parses', () {
    expect(ReminderSettingsModel.fromJson(example()).entity, expected);
  });

  test('the goal fills the reminder body', () {
    expect(expected.bodyIn('ar'), '10 دقائق فقط وتحافظ على أيامك المتتالية');
    expect(expected.defaultPreset.time, const ReminderTime(20, 0));
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
    final settings = ReminderSettingsModel.fromJson(json).entity;
    expect(settings.presets, const [
      ReminderPreset(slot: ReminderSlot.noon, time: ReminderTime(12, 30)),
    ]);
    // The default falls back to an offered time.
    expect(settings.defaultPreset.slot, ReminderSlot.noon);
  });

  test('incomplete settings are rejected', () {
    final json = example()..remove('motivation');
    expect(() => ReminderSettingsModel.fromJson(json), throwsFormatException);
    expect(
      () => ReminderSettingsModel.fromJson(const {}),
      throwsFormatException,
    );
  });

  test('GET /api/v1/settings', () async {
    final adapter = FakeHttpAdapter(
      (_) => FakeResponse(200, body: exampleBody),
    );
    final client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

    final settings = await ReminderSettingsRemoteDataSourceImpl(
      client,
    ).getReminderSettings();

    expect(adapter.requests.single.path, '/api/v1/settings');
    expect(settings.entity, expected);
  });

  test('mock mode serves the bundled example', () async {
    final settings = await ReminderSettingsFakeDataSource(
      _DiskBundle(),
      latency: Duration.zero,
    ).getReminderSettings();
    expect(settings.entity, expected);
  });

  test('the repository maps errors through the error funnel', () async {
    final result = await ReminderSettingsRepositoryImpl(
      _FailingDataSource(),
    ).getReminderSettings();
    expect((result as Err).failure, isA<NetworkFailure>());
  });
}
