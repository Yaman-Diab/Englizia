import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/device_volume.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum KidWelcomePhase {
  /// The parent hands the phone over and turns the sound up.
  handOver,

  /// The guide speaks its welcome.
  speaking,

  /// The guide says "Hello!": the word is highlighted.
  hello,

  /// The welcome is over: "let's play" appears.
  done,

  /// The phone is silent: the child is asked to turn it up.
  muted,
}

final class KidWelcomeState extends Equatable {
  const KidWelcomeState({this.phase = KidWelcomePhase.handOver});

  final KidWelcomePhase phase;

  /// The guide is talking.
  bool get speaking =>
      phase == KidWelcomePhase.speaking || phase == KidWelcomePhase.hello;

  @override
  List<Object?> get props => [phase];
}

/// The kids' welcome (requirements v3.0 §4.5, design "Kid Welcome"), in
/// place of "preparing" on the child path: it starts the account's session,
/// waits for the parent's "done, let's start" (the touch that lets a phone
/// play sound), then the guide speaks its welcome. A silent phone waits for
/// the volume to come up and starts the welcome over.
class KidWelcomeCubit extends Cubit<KidWelcomeState> {
  KidWelcomeCubit(
    this._session,
    this._sound,
    this._volume, {
    this.helloCue = defaultHelloCue,
    this.endCue = defaultEndCue,
  }) : super(const KidWelcomeState());

  final AppSessionController _session;
  final SoundPlayer _sound;
  final DeviceVolume _volume;

  /// When "Hello!" is said, and when the welcome ends, from its start.
  // ASSUMPTION(design): the design's timings, until the recording exists
  // (docs/STATUS.md, D-046); they then come from the recording.
  final Duration helloCue;
  final Duration endCue;
  static const defaultHelloCue = Duration(milliseconds: 2600);
  static const defaultEndCue = Duration(milliseconds: 3900);

  StreamSubscription<bool>? _volumeChanges;

  /// Each welcome gets a number; a newer one, or going back, ends the older.
  int _run = 0;

  /// Starts the new account's session and follows the volume.
  Future<void> start(AuthTokens account) async {
    _volumeChanges ??= _volume.mutedChanges.listen(_onMuted);
    // Router: the kids' welcome stays open when the session starts.
    await _session.signIn(account);
  }

  /// The guide speaks its welcome from the start, if the phone can be heard.
  Future<void> play() async {
    final run = ++_run;
    final muted = await _volume.isMuted();
    if (_stale(run)) return;
    if (muted) {
      emit(const KidWelcomeState(phase: KidWelcomePhase.muted));
      return;
    }
    emit(const KidWelcomeState(phase: KidWelcomePhase.speaking));
    unawaited(_sound.play(AppSound.guideWelcome));
    await Future<void>.delayed(helloCue);
    if (_stale(run)) return;
    emit(const KidWelcomeState(phase: KidWelcomePhase.hello));
    await Future<void>.delayed(endCue - helloCue);
    if (_stale(run)) return;
    emit(const KidWelcomeState(phase: KidWelcomePhase.done));
  }

  /// The replay button: the welcome again, unless the phone is silent.
  Future<void> replay() async {
    if (state.phase == KidWelcomePhase.muted ||
        state.phase == KidWelcomePhase.handOver) {
      return;
    }
    await play();
  }

  /// The word, or the guide, was tapped.
  void sayHello() => unawaited(_sound.play(AppSound.hello));

  /// Back from the child's part returns to the parent's, never to sign-up.
  void handOver() {
    _run++;
    emit(const KidWelcomeState());
  }

  void _onMuted(bool muted) {
    if (!muted && state.phase == KidWelcomePhase.muted) {
      unawaited(play());
    } else if (muted && state.speaking) {
      _run++;
      emit(const KidWelcomeState(phase: KidWelcomePhase.muted));
    }
  }

  bool _stale(int run) => isClosed || run != _run;

  @override
  Future<void> close() async {
    await _volumeChanges?.cancel();
    return super.close();
  }
}
