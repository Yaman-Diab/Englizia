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

final class PlacementIntroState extends Equatable {
  const PlacementIntroState({
    this.load = LoadStatus.loading,
    this.summary,
    this.status,
    this.firstLevel,
    this.failure,
    this.online = true,
    this.trying = false,
  });

  final LoadStatus load;

  /// The published test's duration and stages; null when not known yet.
  final PlacementSummary? summary;

  /// Null when not known yet: offline, the screen reads as a first test.
  final PlacementStatus? status;

  /// Where a learner who skips the test starts; null when the track or its
  /// levels are not known.
  final TrackLevel? firstLevel;
  final Failure? failure;

  /// The test needs a connection; the sound check and skipping do not.
  final bool online;

  /// The sound check is playing.
  final bool trying;

  /// No published test version: the first level stays.
  bool get testUnavailable => failure is NotFoundFailure;

  bool get _testReachable => online && summary != null && status != null;

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
  }) => PlacementIntroState(
    load: load ?? this.load,
    summary: summary ?? this.summary,
    status: status ?? this.status,
    firstLevel: firstLevel ?? this.firstLevel,
    failure: failure != null ? failure() : this.failure,
    online: online ?? this.online,
    trying: trying ?? this.trying,
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

  Future<void> start(String? trackId) async {
    _trackId = trackId;
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
          Err() => null,
        },
        firstLevel: switch (levels) {
          Ok(:final value) when value.isNotEmpty => value.first,
          _ => null,
        },
        failure: () => failure,
      ),
    );
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
