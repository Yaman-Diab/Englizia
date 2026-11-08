import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/sound_catalog.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';

/// What actually makes the sound, kept behind this so [AssetSoundPlayer]'s
/// rules are tested without a phone.
abstract interface class SoundBackend {
  /// Sets how the app's sounds sit with the phone's other audio, once.
  Future<void> configure();

  /// Gets [asset] ready to play at once.
  Future<void> load(String asset);

  /// Plays [asset] from its start at [volume]; one already playing starts
  /// over rather than playing twice over itself. Done once it has played.
  Future<void> play(String asset, double volume);
}

/// The bundled sounds of [soundCatalog] (ADR 9). Plays nothing when the
/// «المؤثرات الصوتية» setting is off or while [holdQuiet] holds, drops the
/// same sound repeated within its `minGap`, and never lets a failure out: a
/// sound that can't play is simply not heard.
final class AssetSoundPlayer implements SoundPlayer {
  AssetSoundPlayer(
    this._backend, {
    required bool Function() enabled,
    Map<AppSound, SoundSpec> catalog = soundCatalog,
    DateTime Function()? now,
  }) : _enabled = enabled,
       _catalog = catalog,
       _now = now ?? DateTime.now;

  final SoundBackend _backend;
  final bool Function() _enabled;
  final Map<AppSound, SoundSpec> _catalog;
  final DateTime Function() _now;

  final _started = <String, DateTime>{};
  var _holds = 0;
  Future<void>? _ready;

  @override
  bool kidsMode = false;

  @override
  Future<void> preload() => _ready ??= _quietly(() async {
    await _backend.configure();
    for (final spec in _catalog.values.where((spec) => spec.preload)) {
      await _backend.load(spec.asset);
      if (spec.kidsAsset case final kids?) await _backend.load(kids);
    }
  });

  @override
  Future<void> play(AppSound sound) async {
    final spec = _catalog[sound];
    if (spec == null || _holds > 0 || !_enabled()) return;
    final asset = (kidsMode ? spec.kidsAsset : null) ?? spec.asset;
    final now = _now();
    if (_started[asset] case final last?
        when now.difference(last) < spec.minGap) {
      return;
    }
    _started[asset] = now;
    await _quietly(() => _backend.play(asset, spec.volume));
  }

  @override
  VoidCallback holdQuiet() {
    _holds++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _holds--;
    };
  }

  Future<void> _quietly(Future<void> Function() work) async {
    try {
      await work();
    } on Object catch (error) {
      AppLogger.debug('A sound did not play: $error');
    }
  }
}
