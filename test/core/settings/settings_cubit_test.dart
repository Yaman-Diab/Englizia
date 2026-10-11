import 'package:bloc_test/bloc_test.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/core/settings/settings_state.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = SettingsStorageService(await SharedPreferences.getInstance());
  });

  test('starts from the stored theme mode', () async {
    await storage.setThemeMode(ThemeMode.dark);
    expect(SettingsCubit(storage).state.themeMode, ThemeMode.dark);
  });

  blocTest<SettingsCubit, SettingsState>(
    'setThemeMode emits and persists the new mode',
    build: () => SettingsCubit(storage),
    act: (cubit) => cubit.setThemeMode(ThemeMode.light),
    expect: () => [const SettingsState(themeMode: ThemeMode.light)],
    verify: (_) => expect(storage.themeMode, ThemeMode.light),
  );

  blocTest<SettingsCubit, SettingsState>(
    'setting the current mode emits nothing',
    build: () => SettingsCubit(storage),
    act: (cubit) => cubit.setThemeMode(ThemeMode.system),
    expect: () => <SettingsState>[],
  );
}
