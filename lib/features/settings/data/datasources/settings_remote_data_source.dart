import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/settings/data/models/effective_settings_model.dart';
import 'package:flutter/services.dart';

abstract interface class SettingsRemoteDataSource {
  Future<EffectiveSettingsModel> getSettings();

  /// `SystemConfigDto` for this phone's platform (the `X-Platform` header).
  Future<Map<String, Object?>> getSystemConfig();
}

final class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  const SettingsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<EffectiveSettingsModel> getSettings() async =>
      EffectiveSettingsModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.settings)),
      );

  @override
  Future<Map<String, Object?>> getSystemConfig() async => asJsonMap(
    await _client.get(
      ApiEndpoints.systemConfig,
      options: ApiClient.publicOptions,
    ),
  );
}

/// Mock mode (`env/mock.json`): the contract's example from the bundled
/// asset the tests also use. Deleted once the endpoint is confirmed.
final class SettingsFakeDataSource implements SettingsRemoteDataSource {
  const SettingsFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
  });

  static const asset = 'assets/mock/settings/effective.json';
  static const configAsset = 'assets/mock/settings/system_config.json';

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<EffectiveSettingsModel> getSettings() async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return EffectiveSettingsModel.fromJson(asJsonMap(ApiClient.unwrap(body)));
  }

  @override
  Future<Map<String, Object?>> getSystemConfig() async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(configAsset));
    return asJsonMap(ApiClient.unwrap(body));
  }
}
