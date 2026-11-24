import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/settings/data/models/effective_settings_model.dart';
import 'package:flutter/services.dart';

abstract interface class SettingsRemoteDataSource {
  Future<EffectiveSettingsModel> getSettings();

  /// `SystemConfigDto` for this phone's platform (the `X-Platform` header).
  Future<Map<String, Object?>> getSystemConfig();
}

final class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  const SettingsRemoteDataSourceImpl(this._client, {AssetBundle? bundled})
    : _bundled = bundled;

  final ApiClient _client;

  /// Where the bundled settings are read from while the server has none.
  final AssetBundle? _bundled;

  // ASSUMPTION(api): the server has no effective settings until v0.5 (the
  // backend's answers of 2026-11-23, settings.md 1): until then onboarding's
  // goal, challenge and reminder read the bundled ones, the goals limited to
  // those `system/config` offers (docs/STATUS.md).
  @override
  Future<EffectiveSettingsModel> getSettings() async {
    try {
      return EffectiveSettingsModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.settings)),
      );
    } on ApiException catch (error) {
      final bundled = _bundled;
      if (bundled == null ||
          error.statusCode != ApiStatusCodes.notFound ||
          error.code != ApiErrorCodes.routeNotFound) {
        rethrow;
      }
      return _bundledSettings(bundled);
    }
  }

  Future<EffectiveSettingsModel> _bundledSettings(AssetBundle bundle) async {
    final json = asJsonMap(
      ApiClient.unwrap(
        jsonDecode(await bundle.loadString(SettingsFakeDataSource.asset)),
      ),
    );
    final offered = {
      for (final option
          in (await getSystemConfig()).readList('dailyGoalOptions') ??
              const <Object?>[])
        if (option is Map) ?option.cast<String, Object?>().readInt('minutes'),
    };
    final motivation = json.readMap('motivation');
    if (offered.isNotEmpty && motivation != null) {
      motivation['dailyGoalOptions'] = [
        for (final option
            in motivation.readList('dailyGoalOptions') ?? const <Object?>[])
          if (option is Map && offered.contains(option['minutes'])) option,
      ];
    }
    return EffectiveSettingsModel.fromJson(json);
  }

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
