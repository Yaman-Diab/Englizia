import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the screen asks the server before moving on.
enum PlacementAction { restart, skip }

final class PlacementIntroState extends Equatable {
  const PlacementIntroState({
    this.load = LoadStatus.loading,
    this.summary,
    this.status,
    this.firstLevel,
    this.failure,
    this.online = true,
    this.trying = false,
    this.running,
    this.done,
    this.actionFailure,
  });

  final LoadStatus load;

  /// The published test's duration and stages; null when not known yet.
  final PlacementSummary? summary;

  /// Null when not known: offline, with nothing saved from before. The screen
  /// then promises nothing, as the learner may well have a result.
  final PlacementStatus? status;

  /// Where a learner who skips the test starts; null when the track or its
  /// levels are not known.
  final TrackLevel? firstLevel;
  final Failure? failure;

  /// The test needs a connection; the sound check and skipping do not.
  final bool online;

  /// The sound check is playing.
  final bool trying;

  /// The action on its way, and the one that just succeeded: the screen moves
  /// on, and says [PlacementIntroCubit.reopened] if it comes back.
  final PlacementAction? running;
  final PlacementAction? done;

  /// Why the action failed, with a retry. Kept apart from [failure], which
  /// decides what the screen can show.
  final Failure? actionFailure;

  bool get busy => running != null || done != null;

  /// No published test version: the first level stays.
  bool get testUnavailable => failure is NotFoundFailure;

  bool get _testReachable =>
      online && summary != null && status != null && !busy;

  /// «ابدأ من جديد» needs the same as starting.
  bool get canRestart => _testReachable;

  bool get canStart => _testReachable && status is! PlacementRetakeLocked;

  PlacementIntroState copyWith({
    LoadStatus? load,
    PlacementSummary? summary,
    PlacementStatus? status,
    TrackLevel? firstLevel,
    Failure? Function()? failure,
    bool? online,
    bool? trying,
    PlacementAction? Function()? running,
    PlacementAction? Function()? done,
    Failure? Function()? actionFailure,
  }) => PlacementIntroState(
    load: load ?? this.load,
    summary: summary ?? this.summary,
    status: status ?? this.status,
    firstLevel: firstLevel ?? this.firstLevel,
    failure: failure != null ? failure() : this.failure,
    online: online ?? this.online,
    trying: trying ?? this.trying,
    running: running != null ? running() : this.running,
    done: done != null ? done() : this.done,
    actionFailure: actionFailure != null ? actionFailure() : this.actionFailure,
  );

  @override
  List<Object?> get props => [
    load,
    summary,
    status,
    firstLevel,
    failure,
    online,
    trying,
    running,
    done,
    actionFailure,
  ];
}

/// The placement test's intro (requirements v3.0 §12.2, design "Placement
/// Intro"): what the test takes and where the learner stands with it. Follows
/// the connection, loading what it missed as soon as it is back.
class PlacementIntroCubit extends Cubit<PlacementIntroState> {
  PlacementIntroCubit(
    this._placement,
    this._tracks,
    this._connectivity,
    this._sounds, {
    this.trialLength = defaultTrialLength,
  }) : super(const PlacementIntroState());

  /// ASSUMPTION(design): the sentence is not recorded yet (STATUS D-048); the
  /// design's own simulation lasts this long.
  static const defaultTrialLength = Duration(milliseconds: 3200);

  final PlacementRepository _placement;
  final TrackRepository _tracks;
  final ConnectivityService _connectivity;
  final SoundPlayer _sounds;
  final Duration trialLength;
  StreamSubscription<bool>? _connection;
  Timer? _trial;
  String? _trackId;
  bool _newAccount = false;
  PlacementAction? _lastAction;

  /// [newAccount] is one that came through onboarding, which can only be on
  /// its first test, connection or not.
  Future<void> start(String? trackId, {bool newAccount = false}) async {
    _trackId = trackId;
    _newAccount = newAccount;
    _connection ??= _connectivity.onlineChanges.listen(_setOnline);
    final online = await _connectivity.isOnline();
    if (isClosed) return;
    emit(state.copyWith(online: online));
    await load();
  }

  Future<void> load() async {
    emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    final trackId = _trackId;
    final (summary, status, levels) = await (
      _placement.getSummary(),
      _placement.getStatus(),
      trackId == null
          ? Future.value(const Ok(<TrackLevel>[]))
          : _tracks.getLevels(trackId),
    ).wait;
    if (isClosed) return;

    final failure = switch ((summary, status)) {
      (Err(:final failure), _) || (_, Err(:final failure)) => failure,
      _ => null,
    };
    // Offline or with no published test, the screen still has something to
    // say; only another failure leaves it with nothing but a retry.
    final usable =
        failure == null ||
        failure is NotFoundFailure ||
        (failure is NetworkFailure && !state.online);
    emit(
      state.copyWith(
        load: usable ? LoadStatus.ready : LoadStatus.failure,
        summary: switch (summary) {
          Ok(:final value) => value,
          Err() => null,
        },
        status: switch (status) {
          Ok(:final value) => value,
          Err() => _newAccount ? const PlacementNotTaken() : null,
        },
        firstLevel: switch (levels) {
          Ok(:final value) when value.isNotEmpty => value.first,
          _ => null,
        },
        failure: () => failure,
      ),
    );
  }

  /// «ابدأ من جديد»: throws away the unfinished test, then the questions open.
  Future<void> restart() => _act(PlacementAction.restart);

  /// «ابدأ من البداية دون اختبار»: tells the server, then the lessons open.
  Future<void> skip() => _act(PlacementAction.skip);

  Future<void> retryAction() async {
    if (_lastAction case final action?) await _act(action);
  }

  Future<void> _act(PlacementAction action) async {
    if (state.busy) return;
    _lastAction = action;
    emit(state.copyWith(running: () => action, actionFailure: () => null));
    final result = await switch (action) {
      PlacementAction.restart => _placement.restartTest(),
      PlacementAction.skip => _placement.deferTest(),
    };
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(running: () => null, done: () => action));
      case Err(:final failure):
        emit(state.copyWith(running: () => null, actionFailure: () => failure));
    }
  }

  /// Back from where the action led: the status may have changed.
  Future<void> reopened() {
    emit(state.copyWith(done: () => null));
    return load();
  }

  /// Plays the sentence that tries the sound, or stops it.
  void toggleTrial() {
    _trial?.cancel();
    if (state.trying) {
      emit(state.copyWith(trying: false));
      return;
    }
    emit(state.copyWith(trying: true));
    unawaited(_sounds.play(AppSound.placementTrial));
    _trial = Timer(trialLength, () {
      if (!isClosed) emit(state.copyWith(trying: false));
    });
  }

  void _setOnline(bool online) {
    emit(state.copyWith(online: online));
    final missing = state.summary == null || state.status == null;
    if (online && missing && state.load != LoadStatus.loading) {
      unawaited(load());
    }
  }

  @override
  Future<void> close() async {
    _trial?.cancel();
    await _connection?.cancel();
    return super.close();
  }
}
