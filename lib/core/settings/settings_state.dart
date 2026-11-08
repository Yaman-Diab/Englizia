import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

final class SettingsState extends Equatable {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.soundEffects = true,
    this.vibration = true,
  });

  final ThemeMode themeMode;

  /// The app's own sounds (answers, stars); kept on this phone only.
  final bool soundEffects;

  /// The app's vibrations; kept on this phone only.
  final bool vibration;

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? soundEffects,
    bool? vibration,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    soundEffects: soundEffects ?? this.soundEffects,
    vibration: vibration ?? this.vibration,
  );

  @override
  List<Object?> get props => [themeMode, soundEffects, vibration];
}
