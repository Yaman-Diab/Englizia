import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

/// A player whose [AppSound.micOn] lasts until the test lets it end.
class _SlowStart implements SoundPlayer {
  final played = <AppSound>[];
  final started = Completer<void>();
  var holds = 0;

  @override
  bool kidsMode = false;

  @override
  Future<void> preload() async {}

  @override
  Future<void> play(AppSound sound) async {
    played.add(sound);
    if (sound == AppSound.micOn) await started.future;
  }

  @override
  VoidCallback holdQuiet() {
    holds++;
    return () => holds--;
  }
}

void main() {
  late FakeSpeechListener speech;
  late _SlowStart sounds;
  late MicCubit mic;

  setUp(() {
    speech = FakeSpeechListener();
    sounds = _SlowStart();
    mic = MicCubit(
      speech,
      FakeMicPermission()..access = MicAccess.granted,
      sounds: sounds,
    );
  });

  tearDown(() => mic.close());

  test('the start sound ends before the microphone records', () async {
    unawaited(mic.listen());
    await pumpEventQueue();

    expect(sounds.played, [AppSound.micOn]);
    expect(speech.listening, isFalse);
    expect(mic.state.phase, MicPhase.listening);

    sounds.started.complete();
    await pumpEventQueue();

    expect(speech.listening, isTrue);
  });

  test('no sound while it records; the stop sound once it stops', () async {
    sounds.started.complete();
    final listening = mic.listen();
    await pumpEventQueue();
    expect(sounds.holds, 1);

    speech.finish();
    await listening;

    expect(sounds.holds, 0);
    expect(sounds.played, [AppSound.micOn, AppSound.micOff]);
    expect(mic.state.phase, MicPhase.heard);
  });

  test('stopped before it began: heard nothing, nothing recorded', () async {
    final listening = mic.listen();
    await pumpEventQueue();
    await mic.stop();

    sounds.started.complete();
    await listening;

    expect(speech.listening, isFalse);
    expect(sounds.holds, 0);
    expect(mic.state.phase, MicPhase.notHeard);
  });

  test('closed during the start sound: nothing starts', () async {
    unawaited(mic.listen());
    await pumpEventQueue();
    await mic.close();

    sounds.started.complete();
    await pumpEventQueue();

    expect(speech.listening, isFalse);
    expect(sounds.holds, 0);
  });
}
