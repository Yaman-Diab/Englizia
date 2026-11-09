import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:flutter/widgets.dart';

/// Plays [sound] from a widget, at the place it belongs (ADR 9): one line,
/// never waited on, and nothing where no player is registered (a widget's
/// own test). Cubits take a [SoundPlayer] instead.
void playSound(AppSound sound) {
  if (!sl.isRegistered<SoundPlayer>()) return;
  unawaited(sl<SoundPlayer>().play(sound));
}

/// Plays [sound] once, as [child] first shows: a card that the next open
/// brings, a result as it arrives.
class SoundOnShow extends StatefulWidget {
  const SoundOnShow({required this.sound, required this.child, super.key});

  final AppSound sound;
  final Widget child;

  @override
  State<SoundOnShow> createState() => _SoundOnShowState();
}

class _SoundOnShowState extends State<SoundOnShow> {
  @override
  void initState() {
    super.initState();
    playSound(widget.sound);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
