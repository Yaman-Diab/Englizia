import 'package:englizia/core/audio/app_sound.dart';
import 'package:flutter/foundation.dart';

/// Plays the app's [AppSound]s. Screens and cubits depend on this interface
/// only, so the audio package, the files and the on/off rules change in one
/// place (ADR 9).
abstract interface class SoundPlayer {
  /// Loads the sounds ahead so the first play is instant; safe to repeat.
  Future<void> preload();

  /// Plays [sound]. Does nothing when sounds are off, the phone is silent or
  /// the file is missing; a sound never blocks or fails a user action. Done
  /// once the sound has played, for the one caller that must wait for it
  /// (the microphone's start).
  Future<void> play(AppSound sound);

  /// Kids mode plays a kid's file where the catalog has one. Home sets it, as
  /// it is the one that knows the learner's audience.
  set kidsMode(bool value);

  /// Keeps every sound quiet until the returned function is called: while
  /// the microphone records, so no sound gets into what it hears, and while
  /// a video or a clip speaks.
  VoidCallback holdQuiet();
}

/// Plays nothing: for tests, and for a build that must be silent.
final class SilentSoundPlayer implements SoundPlayer {
  const SilentSoundPlayer();

  @override
  Future<void> preload() async {}

  @override
  Future<void> play(AppSound sound) async {}

  @override
  set kidsMode(bool value) {}

  @override
  VoidCallback holdQuiet() => () {};
}
