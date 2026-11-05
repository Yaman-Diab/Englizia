import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/core/settings/settings_state.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide UI preferences kept on this phone. The UI language is owned by
/// easy_localization (`context.setLocale`), not by this cubit.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._storage)
    : super(
        SettingsState(
          themeMode: _storage.themeMode,
          soundEffects: _storage.soundEffects,
          vibration: _storage.vibration,
        ),
      ) {
    AppHaptics.enabled = state.vibration;
  }

  final SettingsStorageService _storage;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state.themeMode) return;
    emit(state.copyWith(themeMode: mode));
    await _storage.setThemeMode(mode);
  }

  Future<void> setSoundEffects({required bool on}) async {
    emit(state.copyWith(soundEffects: on));
    await _storage.setSoundEffects(on: on);
  }

  Future<void> setVibration({required bool on}) async {
    AppHaptics.enabled = on;
    emit(state.copyWith(vibration: on));
    await _storage.setVibration(on: on);
  }
}
