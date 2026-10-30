import 'dart:math';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive preferences only. Tokens and personal data never go here.
final class SettingsStorageService {
  SettingsStorageService(this._prefs);

  static const _themeModeKey = 'settings.theme_mode';
  static const _hasLaunchedKey = 'app.has_launched';
  static const _installationIdKey = 'app.installation_id';
  static const _lastSignInKey = 'account.last_sign_in';
  static const _deviceIdKey = 'account.device_id';
  static const _placementStatusKey = 'account.placement_status';
  static const _placementProgressKey = 'account.placement_progress';
  static const _emailReminderKey = 'account.email_reminder_hidden_until';
  static const _lessonProgressKey = 'account.lesson_progress';

  final SharedPreferences _prefs;

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_prefs.getString(_themeModeKey)] ??
      ThemeMode.system;

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }

  bool get hasLaunchedBefore => _prefs.getBool(_hasLaunchedKey) ?? false;

  Future<void> markLaunched() async {
    await _prefs.setBool(_hasLaunchedKey, true);
  }

  /// The provider used for the last sign-in (`google`, `apple`), for the
  /// «آخر دخول لك» badge. Kept on the phone only (S §5.1).
  String? get lastSignInMethod => _prefs.getString(_lastSignInKey);

  Future<void> setLastSignInMethod(String method) async {
    await _prefs.setString(_lastSignInKey, method);
  }

  /// The id the server gave this phone. Sent back so that signing in again
  /// is not a new device; a sign-out keeps it.
  String? get deviceId => _prefs.getString(_deviceIdKey);

  Future<void> setDeviceId(String id) async {
    await _prefs.setString(_deviceIdKey, id);
  }

  /// The last placement status the server sent, as JSON, for the test's
  /// intro while offline. A level and some counts: nothing that names anyone.
  String? get placementStatus => _prefs.getString(_placementStatusKey);

  Future<void> setPlacementStatus(String json) async {
    await _prefs.setString(_placementStatusKey, json);
  }

  Future<void> clearPlacementStatus() async {
    await _prefs.remove(_placementStatusKey);
  }

  /// The answers of the placement test not on the server yet and how often
  /// each clip was played, as JSON, so an answer given is never lost.
  String? get placementProgress => _prefs.getString(_placementProgressKey);

  Future<void> setPlacementProgress(String json) async {
    await _prefs.setString(_placementProgressKey, json);
  }

  Future<void> clearPlacementProgress() async {
    await _prefs.remove(_placementProgressKey);
  }

  /// Where each lesson's exercises stand on this phone and the answers not on
  /// the server yet, as JSON, so nothing is lost offline.
  String? get lessonProgress => _prefs.getString(_lessonProgressKey);

  Future<void> setLessonProgress(String json) async {
    await _prefs.setString(_lessonProgressKey, json);
  }

  /// Until when the reminder to confirm the email stays hidden.
  DateTime? get emailReminderHiddenUntil =>
      DateTime.tryParse(_prefs.getString(_emailReminderKey) ?? '');

  Future<void> setEmailReminderHiddenUntil(DateTime until) async {
    await _prefs.setString(_emailReminderKey, until.toUtc().toIso8601String());
  }

  /// Forgets what belongs to the account in use, when another may follow.
  /// Never fails its caller: starting or ending a session must go on.
  Future<void> clearAccountData() async {
    try {
      await clearPlacementStatus();
      await clearPlacementProgress();
      await _prefs.remove(_emailReminderKey);
      await _prefs.remove(_lessonProgressKey);
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Clearing account data failed');
    }
  }

  /// A random id for this install, made on first use. Not personal: the
  /// guest account is tied to it, and a retried request reuses it (ADR 10).
  Future<String> installationId() async {
    if (_prefs.getString(_installationIdKey) case final saved?) return saved;
    final id = randomId();
    await _prefs.setString(_installationIdKey, id);
    return id;
  }

  /// 128 random bits as a version-4 UUID.
  static String randomId() {
    final random = Random.secure();
    final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [
      for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
