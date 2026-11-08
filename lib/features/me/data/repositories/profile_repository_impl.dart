import 'dart:convert';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:englizia/features/me/data/datasources/profile_remote_data_source.dart';
import 'package:englizia/features/me/data/models/profile_model.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';

final class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(
    this._remote, {
    required SettingsStorageService settings,
    required TokenStorage tokens,
    this.devicePlatform,
  }) : _settings = settings,
       _tokens = tokens;

  final ProfileRemoteDataSource _remote;
  final SettingsStorageService _settings;
  final TokenStorage _tokens;

  /// The server's `DevicePlatform` for this phone, or null when it has none.
  final String? devicePlatform;

  @override
  Profile? get keptProfile {
    final saved = _settings.profile;
    if (saved == null) return null;
    try {
      return ProfileModel(asJsonMap(jsonDecode(saved))).toEntity();
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Kept profile unreadable');
      return null;
    }
  }

  @override
  Future<Result<Profile>> getProfile() => guard(() async {
    final model = await _remote.getProfile();
    final profile = model.toEntity();
    try {
      await _settings.setProfile(jsonEncode(model.json));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Keeping the profile failed');
    }
    return profile;
  });

  @override
  Future<Result<void>> rename(String name) => guard(() => _remote.rename(name));

  @override
  Future<Result<void>> switchTrack(String enrollmentId) =>
      guard(() => _remote.switchTrack(enrollmentId));

  @override
  Future<Result<void>> changeLevel(String enrollmentId, String levelId) =>
      guard(() => _remote.changeLevel(enrollmentId, levelId));

  @override
  Future<Result<Preferences>> getPreferences() => guard(() async {
    final preferences = ProfileModel.preferences(
      await _remote.getPreferences(),
    );
    if (preferences == null) {
      throw const FormatException('Preferences without a goal');
    }
    return preferences;
  });

  @override
  Future<Result<void>> savePreferences(Preferences preferences) => guard(
    () => _remote.savePreferences(ProfileModel.preferencesToJson(preferences)),
  );

  @override
  Future<Result<void>> changePassword({
    required String current,
    required String next,
  }) => guard(() async {
    final tokens = await _remote.changePassword(
      current: current,
      next: next,
      deviceId: _settings.deviceId,
      platform: devicePlatform,
    );
    // The server ends the account's sessions, this phone's own included, and
    // answers with the one to carry on with.
    if (tokens == null) return;
    await _tokens.write(tokens);
    if (tokens.deviceId case final id? when id != _settings.deviceId) {
      await _settings.setDeviceId(id);
    }
  });

  @override
  Future<Result<void>> deleteAccount({String? password}) =>
      guard(() => _remote.deleteAccount(password));

  @override
  bool firstViewOn(DateTime day) {
    final key = DateTime(
      day.year,
      day.month,
      day.day,
    ).toIso8601String().substring(0, 10);
    if (_settings.meSeenDay == key) return false;
    _settings.setMeSeenDay(key).catchError((Object error) {
      AppLogger.error(error, StackTrace.current, 'Keeping the day failed');
    });
    return true;
  }
}
