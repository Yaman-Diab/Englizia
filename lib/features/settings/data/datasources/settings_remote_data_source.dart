import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/notifications/data/models/reminder_settings_model.dart';
import 'package:flutter/services.dart';

abstract interface class ReminderSettingsRemoteDataSource {
  Future<ReminderSettingsModel> getReminderSettings();
}

final class ReminderSettingsRemoteDataSourceImpl
    implements ReminderSettingsRemoteDataSource {
  const ReminderSettingsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<ReminderSettingsModel> getReminderSettings() async =>
      ReminderSettingsModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.settings)),
      );
}

/// Mock mode (`env/mock.json`): the contract's example from the bundled
/// asset the tests also use. Deleted once the endpoint is confirmed.
final class ReminderSettingsFakeDataSource
    implements ReminderSettingsRemoteDataSource {
  const ReminderSettingsFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
  });

  static const asset = 'assets/mock/settings/effective.json';

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<ReminderSettingsModel> getReminderSettings() async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return ReminderSettingsModel.fromJson(asJsonMap(ApiClient.unwrap(body)));
  }
}
