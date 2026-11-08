import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/audio/speech_listener.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum MicPhase {
  idle,
  listening,

  /// Stopped, and the engine is finishing what it heard.
  thinking,

  /// Heard nothing: not an attempt, and ready again at once (S §7.5).
  notHeard,

  /// The phone said no; the settings can change that.
  denied,

  /// Something was understood: `transcript`.
  heard,
}

final class MicState extends Equatable {
  const MicState({
    this.phase = MicPhase.idle,
    this.seconds = 0,
    this.transcript = '',
  });

  final MicPhase phase;
  final int seconds;
  final String transcript;

  @override
  List<Object?> get props => [phase, seconds, transcript];
}

/// One press to start and one to stop (requirements v3.0 §7.5). Its own cubit,
/// shared by the lessons' questions, shadowing and conversation, which have no
/// business with it (ADR 11). The level changes many times a second, so
/// it goes on [levels], never through the state.
class MicCubit extends Cubit<MicState> {
  MicCubit(
    this._listener,
    this._permission, {
    SoundPlayer sounds = const SilentSoundPlayer(),
  }) : _sounds = sounds,
       super(const MicState());

  /// Stops by itself after this much silence, or this long (S §7.5).
  static const _silence = Duration(seconds: 2);
  static const _limit = Duration(seconds: 15);

  final SpeechListener _listener;
  final MicPermission _permission;
  final SoundPlayer _sounds;
  final _levels = StreamController<double>.broadcast();
  Timer? _clock;

  Stream<double> get levels => _levels.stream;

  Future<MicAccess> access() => _permission.status();

  /// Asks the phone, after the learner has read why, and listens if it agrees.
  Future<void> ask() async {
    final access = await _permission.request();
    if (isClosed) return;
    if (access == MicAccess.granted) {
      await listen();
    } else {
      emit(const MicState(phase: MicPhase.denied));
    }
  }

  void showDenied() => emit(const MicState(phase: MicPhase.denied));

  Future<void> openSettings() => _permission.openSettings();

  /// Back from the settings, it may be allowed now.
  Future<void> recheck() async {
    if (state.phase != MicPhase.denied) return;
    if (await _permission.status() == MicAccess.granted && !isClosed) {
      reset();
    }
  }

  /// Stops after [silence] or at [limit]: by default as a sentence to repeat.
  Future<void> listen({Duration? silence, Duration? limit}) async {
    if (state.phase == MicPhase.listening || state.phase == MicPhase.thinking) {
      return;
    }
    emit(const MicState(phase: MicPhase.listening));
    // Heard to its end before the engine records, so it isn't recorded;
    // then nothing sounds until it stops.
    await _sounds.play(AppSound.micOn);
    if (isClosed) return;
    if (state.phase != MicPhase.listening) {
      // Stopped before it began: heard nothing, ready again.
      if (state.phase == MicPhase.thinking) {
        emit(const MicState(phase: MicPhase.notHeard));
      }
      return;
    }
    final release = _sounds.holdQuiet();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed && state.phase == MicPhase.listening) {
        emit(MicState(phase: MicPhase.listening, seconds: state.seconds + 1));
      }
    });
    final words = await _listener.listen(
      silence: silence ?? _silence,
      limit: limit ?? _limit,
      onLevel: _levels.add,
    );
    release();
    unawaited(_sounds.play(AppSound.micOff));
    _clock?.cancel();
    if (isClosed || state.phase == MicPhase.idle) return;
    emit(
      words == null || words.trim().isEmpty
          ? const MicState(phase: MicPhase.notHeard)
          : MicState(phase: MicPhase.heard, transcript: words),
    );
  }

  /// The press that stops it.
  Future<void> stop() async {
    if (state.phase != MicPhase.listening) return;
    _clock?.cancel();
    emit(const MicState(phase: MicPhase.thinking));
    await _listener.stop();
  }

  /// A new question or a new try.
  void reset() {
    _clock?.cancel();
    if (state.phase == MicPhase.listening) {
      unawaited(_listener.stop());
    }
    emit(const MicState());
  }

  @override
  Future<void> close() async {
    _clock?.cancel();
    if (state.phase == MicPhase.listening) {
      unawaited(_listener.stop());
    }
    await _levels.close();
    return super.close();
  }
}
