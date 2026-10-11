import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive preferences only. Tokens and personal data never go here.
final class SettingsStorageService {
  SettingsStorageService(this._prefs);

  static const _themeModeKey = 'settings.theme_mode';
  static const _hasLaunchedKey = 'app.has_launched';

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
}
