import 'dart:convert';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:englizia/features/settings/data/models/effective_settings_model.dart';
import 'package:englizia/features/settings/data/models/version_policy_model.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';

final class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(
    this._remote,
    this._storage, {
    required String? platform,
  }) : _platform = platform;

  final SettingsRemoteDataSource _remote;
  final SettingsStorageService _storage;
  final String? _platform;
  EffectiveSettingsModel? _loaded;

  /// A response is kept for the session, so each screen that reads a setting
  /// does not fetch it again; a failure is retried by the next call.
  Future<Result<EffectiveSettingsModel>> _settings() async {
    if (_loaded case final settings?) return Ok(settings);
    final result = await guard(_remote.getSettings);
    if (result case Ok(:final value)) _loaded = value;
    return result;
  }

  @override
  Future<Result<EffectiveSettings>> getSettings() async {
    final settings = await _settings();
    if (settings case Err(:final failure)) return Err(failure);
    final result = await guard(() async => _loaded!.entity);
    // An incomplete response is fetched again by the next call.
    if (result is Err) _loaded = null;
    return result;
  }

  @override
  Future<Result<VersionPolicy>> getVersionPolicy({
    bool keptOnly = false,
  }) async {
    if (keptOnly) {
      return switch (_kept()) {
        final kept? => Ok(kept),
        null => const Err(UnknownFailure()),
      };
    }
    switch (await _settings()) {
      case Ok(:final value):
        final policy = value.versionsFor(_platform);
        await _keep(policy);
        return Ok(policy);
      case Err(:final failure):
        final kept = _kept();
        return kept == null ? Err(failure) : Ok(kept);
    }
  }

  Future<void> _keep(VersionPolicy policy) async {
    try {
      await _storage.setVersionPolicy(
        jsonEncode(VersionPolicyModel(policy).toJson()),
      );
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Keeping the versions failed');
    }
  }

  VersionPolicy? _kept() {
    final json = _storage.versionPolicy;
    if (json == null) return null;
    try {
      return VersionPolicyModel.fromJson(asJsonMap(jsonDecode(json))).entity;
    } on FormatException {
      return null;
    }
  }
}
