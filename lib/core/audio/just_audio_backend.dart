import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:englizia/core/audio/asset_sound_player.dart';
import 'package:just_audio/just_audio.dart';

/// [SoundBackend] on `just_audio`, one player per file, kept ready (ADR 9).
///
/// The sounds sit with the phone's own audio as effects do: on iOS the
/// session is `ambient`, so the silent switch silences them and the
/// learner's music goes on under them; on Android they are sonification and
/// ask for no audio focus, so nothing the learner listens to is paused.
final class JustAudioBackend implements SoundBackend {
  final _players = <String, Future<AudioPlayer>>{};

  @override
  Future<void> configure() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.assistanceSonification,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ),
    );
  }

  @override
  Future<void> load(String asset) => _player(asset);

  @override
  Future<void> play(String asset, double volume) async {
    final player = await _player(asset);
    await player.setVolume(volume);
    // At its end a player stays playing: going back to the start plays it
    // again, and one still sounding starts over instead of doubling.
    await player.seek(Duration.zero);
    if (!player.playing) unawaited(player.play().catchError((Object _) {}));
    final length = player.duration;
    if (length != null) await Future<void>.delayed(length);
  }

  Future<AudioPlayer> _player(String asset) => _players[asset] ??= () async {
    final player = AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
    );
    try {
      await player.setAsset(asset);
      return player;
    } on Object {
      // Tried again next time, as a file may load once the app is back.
      unawaited(_players.remove(asset));
      await player.dispose();
      rethrow;
    }
  }();
}
