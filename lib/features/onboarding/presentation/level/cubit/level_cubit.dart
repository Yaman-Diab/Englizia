import 'dart:async';

import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/english_level_choice.dart';
import 'package:englizia/features/onboarding/presentation/level/cubit/level_state.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "How much English do you know?": loads what the placement test takes and
/// where a beginner starts, and follows the connection: the test can only be
/// chosen online, and losing the connection takes the choice back.
class LevelCubit extends Cubit<LevelState> {
  LevelCubit(this._placement, this._tracks, this._connectivity)
    : super(const LevelState());

  final PlacementRepository _placement;
  final TrackRepository _tracks;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connection;
  String? _trackId;

  /// Loads the details for the learner's [trackId] and starts following
  /// the connection.
  Future<void> start(String? trackId) async {
    _trackId = trackId;
    _connection ??= _connectivity.onlineChanges.listen(_setOnline);
    final online = await _connectivity.isOnline();
    if (isClosed) return;
    _setOnline(online);
    await load();
  }

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    final trackId = _trackId;
    final (summary, levels) = await (
      _placement.getSummary(),
      trackId == null
          ? Future.value(const Ok(<TrackLevel>[]))
          : _tracks.getLevels(trackId),
    ).wait;
    if (isClosed) return;

    final failure = switch ((summary, levels)) {
      (Err(:final failure), _) || (_, Err(:final failure)) => failure,
      _ => null,
    };
    emit(
      state.copyWith(
        status: failure == null ? LoadStatus.ready : LoadStatus.failure,
        summary: () => switch (summary) {
          Ok(:final value) => value,
          Err() => null,
        },
        firstLevel: () => switch (levels) {
          Ok(:final value) when value.isNotEmpty => value.first,
          _ => null,
        },
        failure: () => failure,
      ),
    );
  }

  void choose(EnglishLevelChoice choice) {
    if (choice == EnglishLevelChoice.some && !state.online) return;
    emit(state.copyWith(choice: () => choice));
  }

  void _setOnline(bool online) => emit(
    state.copyWith(
      online: online,
      choice: !online && state.choice == EnglishLevelChoice.some
          ? () => null
          : null,
    ),
  );

  @override
  Future<void> close() async {
    await _connection?.cancel();
    return super.close();
  }
}
