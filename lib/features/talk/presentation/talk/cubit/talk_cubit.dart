import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/domain/repositories/talk_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class TalkState extends Equatable {
  const TalkState({
    this.load = LoadStatus.loading,
    this.failure,
    this.home,
    this.online = true,
  });

  final LoadStatus load;
  final Failure? failure;
  final TalkHome? home;

  /// A conversation needs the internet: offline, nothing starts (S §8.6).
  final bool online;

  /// Today's AI conversations are used up; written ones still open.
  bool get quotaOut => (home?.quotaLeft ?? 1) <= 0;

  /// Whether [scenario] can be opened now.
  bool canOpen(ScenarioCard scenario) =>
      online && !scenario.locked && !(quotaOut && scenario.kind == TalkKind.ai);

  TalkState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    TalkHome? home,
    bool? online,
  }) => TalkState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    home: home ?? this.home,
    online: online ?? this.online,
  );

  @override
  List<Object?> get props => [load, failure, home, online];
}

/// «تحدّث» (requirements v3.0 §8.6, design "Talk"): the scenarios of the units
/// the learner has reached, and the AI conversations left today.
class TalkCubit extends Cubit<TalkState> {
  TalkCubit(this._talk, this._connectivity) : super(const TalkState());

  final TalkRepository _talk;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _changes;

  Future<void> start() async {
    if (_talk.keptHome case final kept?) {
      emit(state.copyWith(load: LoadStatus.ready, home: kept));
    }
    _changes ??= _connectivity.onlineChanges.listen((online) {
      if (isClosed) return;
      emit(state.copyWith(online: online));
      if (online) unawaited(refresh());
    });
    final online = await _connectivity.isOnline();
    if (isClosed) return;
    emit(state.copyWith(online: online));
    await refresh();
  }

  /// Back from a conversation, today's count and the scenario's status change.
  Future<void> refresh() async {
    if (state.home == null) {
      emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    }
    final result = await _talk.getHome();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            failure: () => null,
            home: value,
          ),
        );
      case Err(:final failure):
        if (state.home == null) {
          emit(
            state.copyWith(load: LoadStatus.failure, failure: () => failure),
          );
        }
    }
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
