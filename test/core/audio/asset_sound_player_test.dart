import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/asset_sound_player.dart';
import 'package:englizia/core/audio/sound_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

class _Backend implements SoundBackend {
  final played = <(String, double)>[];
  final loaded = <String>[];
  var configured = 0;
  Object? fails;

  @override
  Future<void> configure() async => configured++;

  @override
  Future<void> load(String asset) async {
    if (fails case final error?) throw error;
    loaded.add(asset);
  }

  @override
  Future<void> play(String asset, double volume) async {
    if (fails case final error?) throw error;
    played.add((asset, volume));
  }
}

void main() {
  late _Backend backend;
  late bool enabled;
  late DateTime now;
  late AssetSoundPlayer player;

  setUp(() {
    backend = _Backend();
    enabled = true;
    now = DateTime(2026, 11, 9, 10);
    player = AssetSoundPlayer(backend, enabled: () => enabled, now: () => now);
  });

  test('plays the catalog\'s file at its volume', () async {
    await player.play(AppSound.correct);

    expect(backend.played, [('assets/sounds/correct.wav', .7)]);
  });

  test('kids mode plays the kids\' file where there is one', () async {
    player.kidsMode = true;

    await player.play(AppSound.correct);
    await player.play(AppSound.tap);

    expect(backend.played.map((p) => p.$1), [
      'assets/sounds/kids/correct.wav',
      // No kids' tap: the grown-ups' one.
      'assets/sounds/tap.wav',
    ]);
  });

  test('the «المؤثرات الصوتية» setting turned off plays nothing', () async {
    enabled = false;

    await player.play(AppSound.lessonComplete);

    expect(backend.played, isEmpty);
  });

  test('nothing plays while held quiet, and plays again once let go', () async {
    final release = player.holdQuiet();
    await player.play(AppSound.correct);
    expect(backend.played, isEmpty);

    release();
    // Letting go twice doesn't let go of someone else's hold.
    final other = player.holdQuiet();
    release();
    await player.play(AppSound.correct);
    expect(backend.played, isEmpty);

    other();
    await player.play(AppSound.correct);
    expect(backend.played, hasLength(1));
  });

  test('the same sound again too soon is dropped, later it plays', () async {
    await player.play(AppSound.tap);
    now = now.add(const Duration(milliseconds: 20));
    await player.play(AppSound.tap);
    expect(backend.played, hasLength(1));

    now = now.add(SoundSpec.defaultGap);
    await player.play(AppSound.tap);
    expect(backend.played, hasLength(2));
  });

  test('a tick can\'t come faster than its gap', () async {
    for (var i = 0; i < 10; i++) {
      await player.play(AppSound.xpTick);
      now = now.add(const Duration(milliseconds: 20));
    }

    // 200 ms of ticks every 20 ms, 70 ms apart at the most: three.
    expect(backend.played, hasLength(3));
  });

  test('two different sounds at once both play', () async {
    await player.play(AppSound.achievement);
    await player.play(AppSound.islandUnlock);

    expect(backend.played, hasLength(2));
  });

  test('a sound that fails to play is simply not heard', () async {
    backend.fails = StateError('no audio');

    await expectLater(player.play(AppSound.correct), completes);
    await expectLater(player.preload(), completes);
  });

  test('the guide\'s voice is not an effect: no file, no sound', () async {
    await player.play(AppSound.guideWelcome);
    await player.play(AppSound.placementTrial);

    expect(backend.played, isEmpty);
  });

  test('preloads the sounds a touch waits on, once, both sets', () async {
    await player.preload();
    await player.preload();

    expect(backend.configured, 1);
    expect(
      backend.loaded,
      containsAll([
        'assets/sounds/correct.wav',
        'assets/sounds/kids/correct.wav',
        'assets/sounds/incorrect.wav',
        'assets/sounds/tap.wav',
        'assets/sounds/mic_on.wav',
      ]),
    );
    expect(backend.loaded, isNot(contains('assets/sounds/achievement.wav')));
  });
}
