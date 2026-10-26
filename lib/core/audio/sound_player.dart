import 'package:englizia/core/audio/app_sound.dart';

/// Plays the app's [AppSound]s. Screens and cubits depend on this interface
/// only, so the audio package, the files and the on/off rules change in one
/// place (ADR 9).
abstract interface class SoundPlayer {
  /// Loads the sounds ahead so the first play is instant; safe to repeat.
  Future<void> preload();

  /// Plays [sound]. Does nothing when sounds are off, the phone is silent or
  /// the file is missing; a sound never blocks or fails a user action.
  Future<void> play(AppSound sound);
}

/// The app makes no sound yet (owner's decision, 2026-10-26): callers can
/// already ask for sounds, and nothing plays.
final class SilentSoundPlayer implements SoundPlayer {
  const SilentSoundPlayer();

  @override
  Future<void> preload() async {}

  @override
  Future<void> play(AppSound sound) async {}
}
