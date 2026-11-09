import 'package:englizia/core/audio/app_sound.dart';

/// One sound's file and how it plays. Files live in `assets/sounds/` (where
/// `LICENSES.md` says where each came from); a kids' file in
/// `assets/sounds/kids/`.
final class SoundSpec {
  const SoundSpec(
    this.file, {
    this.kids,
    this.volume = 1,
    this.preload = false,
    this.minGap = defaultGap,
  });

  /// Under `assets/sounds/`.
  final String file;

  /// Under `assets/sounds/kids/`, played instead of [file] in kids mode.
  final String? kids;

  /// 0–1, to even the sounds out against each other: every file is
  /// normalized to the same peak, and a tap must stay quieter than a lesson's
  /// end.
  final double volume;

  /// Loaded when the app starts, for the sounds a touch waits on.
  final bool preload;

  /// The same sound again sooner than this is dropped: a fast double tap
  /// plays once, and a count can't tick faster.
  final Duration minGap;
  static const defaultGap = Duration(milliseconds: 40);

  static const folder = 'assets/sounds';

  String get asset => '$folder/$file';

  String? get kidsAsset => switch (kids) {
    final kids? => '$folder/kids/$kids',
    null => null,
  };
}

/// Every effect the app plays: change a sound by changing its line, add one
/// with a value in [AppSound] and a line here. The volumes even out the
/// files' own loudness (the loudest 100 ms of each, as
/// `tool/sounds/synth.py` prints it), so each sits where it should against
/// [AppSound.correct]: a wrong answer 1.5 dB under it, a tap 7, the
/// microphone 5, a tick 10; a lesson's end and an achievement above it. The guide's recorded voice
/// ([AppSound.guideWelcome], [AppSound.hello], [AppSound.placementTrial]) is
/// not an effect and has no line: it stays silent until its recordings come.
const soundCatalog = <AppSound, SoundSpec>{
  AppSound.correct: SoundSpec(
    'correct.wav',
    kids: 'correct.wav',
    volume: .7,
    preload: true,
  ),
  AppSound.incorrect: SoundSpec(
    'incorrect.wav',
    kids: 'incorrect.wav',
    volume: .55,
    preload: true,
  ),
  AppSound.tap: SoundSpec('tap.wav', volume: .75, preload: true),
  AppSound.lessonComplete: SoundSpec(
    'lesson_complete.wav',
    kids: 'lesson_complete.wav',
    volume: 1,
  ),
  AppSound.achievement: SoundSpec('achievement.wav'),
  AppSound.islandUnlock: SoundSpec('island_unlock.wav', volume: .9),
  AppSound.goalReached: SoundSpec('daily_goal.wav', volume: .7),
  AppSound.micOn: SoundSpec('mic_on.wav', volume: .32, preload: true),
  AppSound.micOff: SoundSpec('mic_off.wav', volume: .32),
  AppSound.saveWord: SoundSpec('save_word.wav', volume: .45),
  AppSound.freeze: SoundSpec('freeze.wav', volume: .95),
  AppSound.notification: SoundSpec('notification.wav', volume: .8),
  AppSound.xpTick: SoundSpec(
    'xp_tick.wav',
    volume: .35,
    minGap: Duration(milliseconds: 70),
  ),
  AppSound.cardFlip: SoundSpec('card_flip.wav', volume: .65),
  AppSound.kidsStar: SoundSpec('kids/star.wav', volume: .6),
  AppSound.bulbul: SoundSpec('kids/bulbul.wav', volume: .6),
};
