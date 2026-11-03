import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/domain/repositories/unit_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class UnitState extends Equatable {
  const UnitState({
    this.load = LoadStatus.loading,
    this.failure,
    this.plan,
    this.online = true,
    this.goalsOpen = false,
    this.settling,
    this.speaking = false,
  });

  final LoadStatus load;
  final Failure? failure;
  final UnitPlan? plan;
  final bool online;
  final bool goalsOpen;

  /// A lesson just completed: its mark fills and its line grows, and only
  /// then does the chain move on to the next one.
  final String? settling;

  /// Kids: the guide says the unit's name.
  final bool speaking;

  UnitLessonStatus status(int index) {
    final plan = this.plan!;
    if (settling == null) return plan.status(index);
    final lesson = plan.lessons[index];
    if (lesson.done) return UnitLessonStatus.done;
    return plan.ordered || lesson.isReview
        ? UnitLessonStatus.locked
        : UnitLessonStatus.open;
  }

  /// Offline, only what is kept on the phone opens (S §6.2).
  bool available(UnitLesson lesson) => online || lesson.kept;

  UnitState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    UnitPlan? plan,
    bool? online,
    bool? goalsOpen,
    String? Function()? settling,
    bool? speaking,
  }) => UnitState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    plan: plan ?? this.plan,
    online: online ?? this.online,
    goalsOpen: goalsOpen ?? this.goalsOpen,
    settling: settling != null ? settling() : this.settling,
    speaking: speaking ?? this.speaking,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    plan,
    online,
    goalsOpen,
    settling,
    speaking,
  ];
}

/// A unit's screen (S §6.2, design "Unit"): what it teaches and its lessons,
/// merged with what the phone knows (completions on their way, where a lesson
/// left off, what opens offline).
class UnitCubit extends Cubit<UnitState> {
  UnitCubit(
    this._units,
    this._lessons,
    this._connectivity,
    ClipPlayer player, {
    required this.unitId,
  }) : _voice = ClipPlayback(player),
       super(const UnitState());

  final UnitRepository _units;
  final LessonRepository _lessons;
  final ConnectivityService _connectivity;
  final ClipPlayback _voice;
  final String unitId;
  StreamSubscription<bool>? _changes;
  var _greeted = false;

  Future<void> start() async {
    if (_units.keptUnit(unitId) case final kept?) _show(kept);
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

  Future<void> refresh() async {
    if (state.plan == null) {
      emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    }
    final result = await _units.getUnit(unitId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _show(value);
      case Err(:final failure):
        if (state.plan == null) {
          emit(
            state.copyWith(load: LoadStatus.failure, failure: () => failure),
          );
        }
    }
  }

  /// Back on the screen: a lesson completed meanwhile moves the chain on.
  Future<void> returned() async {
    final before = state.plan;
    if (before == null) return;
    _show(before);
    await refresh();
  }

  void _show(UnitPlan unit) {
    final plan = unit.withPhone(_lessons.onPhone);
    final before = state.plan;
    final justDone = before == null
        ? null
        : [
            for (final (index, lesson) in plan.lessons.indexed)
              if (lesson.done &&
                  index < before.lessons.length &&
                  before.lessons[index].id == lesson.id &&
                  !before.lessons[index].done)
                lesson.id,
          ].lastOrNull;
    final firstShow = before == null;
    emit(
      state.copyWith(
        load: LoadStatus.ready,
        failure: () => null,
        plan: plan,
        goalsOpen: firstShow ? !_units.goalsSeen(unitId) : null,
        settling: justDone == null ? null : () => justDone,
      ),
    );
    if (firstShow) unawaited(_units.setGoalsSeen(unitId));
    if (plan.kids && !_greeted) {
      _greeted = true;
      unawaited(sayUnit());
    }
  }

  /// The chain has shown the lesson done: the next one becomes current.
  void settled() => emit(state.copyWith(settling: () => null));

  void toggleGoals() => emit(state.copyWith(goalsOpen: !state.goalsOpen));

  /// Kids: the guide says the unit's name.
  Future<void> sayUnit() async {
    final url = state.plan?.titleAudioUrl;
    if (url == null) return;
    emit(state.copyWith(speaking: true));
    void done() {
      if (!isClosed) emit(state.copyWith(speaking: false));
    }

    final outcome = await _voice.start(url, onEnd: done);
    if (outcome is! ClipPlaying) done();
  }

  /// Kids: a lesson's card says its name.
  Future<void> sayLesson(UnitLesson lesson) async {
    final url = lesson.audioUrl;
    if (url == null) return;
    if (state.speaking) emit(state.copyWith(speaking: false));
    await _voice.start(url, onEnd: () {});
  }

  @override
  Future<void> close() {
    _voice.stop();
    unawaited(_changes?.cancel());
    return super.close();
  }
}
