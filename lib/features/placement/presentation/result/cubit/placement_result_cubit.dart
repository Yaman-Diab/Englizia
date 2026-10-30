import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum PlacementResultView {
  /// The server is working it out.
  loading,

  /// Nothing to show for another reason than the connection.
  failed,

  /// No connection: the answers are safe, and the result waits.
  offline,
  ready,
}

final class PlacementResultState extends Equatable {
  const PlacementResultState({
    this.view = PlacementResultView.loading,
    this.failure,
    this.result,
    this.levelIndex = 0,
    this.lowered = false,
    this.retrying = false,
    this.accepting = false,
    this.accepted = false,
    this.actionFailure,
  });

  final PlacementResultView view;
  final Failure? failure;
  final PlacementResult? result;

  /// Where the learner will start: as measured, or one lower by choice. The
  /// skills stay as measured.
  final int levelIndex;
  final bool lowered;

  /// Trying again after no connection.
  final bool retrying;

  /// Telling the server where to start.
  final bool accepting;

  /// It knows: the lessons follow.
  final bool accepted;
  final Failure? actionFailure;

  PlacementLevel? get level => result?.levels[levelIndex];

  /// The level below, which the learner may choose once.
  PlacementLevel? get lowerLevel => result == null || lowered || levelIndex == 0
      ? null
      : result!.levels[levelIndex - 1];

  bool get isFirstLevel => levelIndex == 0;

  bool get isTopLevel =>
      !lowered && result != null && levelIndex == result!.levels.length - 1;

  PlacementResultState copyWith({
    PlacementResultView? view,
    Failure? Function()? failure,
    PlacementResult? result,
    int? levelIndex,
    bool? lowered,
    bool? retrying,
    bool? accepting,
    bool? accepted,
    Failure? Function()? actionFailure,
  }) => PlacementResultState(
    view: view ?? this.view,
    failure: failure != null ? failure() : this.failure,
    result: result ?? this.result,
    levelIndex: levelIndex ?? this.levelIndex,
    lowered: lowered ?? this.lowered,
    retrying: retrying ?? this.retrying,
    accepting: accepting ?? this.accepting,
    accepted: accepted ?? this.accepted,
    actionFailure: actionFailure != null ? actionFailure() : this.actionFailure,
  );

  @override
  List<Object?> get props => [
    view,
    failure,
    result,
    levelIndex,
    lowered,
    retrying,
    accepting,
    accepted,
    actionFailure,
  ];
}

/// The placement test's result (requirements v3.0 §12.2, design "Placement
/// Result"): an honest estimate, marked by the server. The learner may start
/// one level lower, after confirming, and the server hears only of the final
/// choice.
class PlacementResultCubit extends Cubit<PlacementResultState> {
  PlacementResultCubit(this._placement, {required String attemptId})
    : _attemptId = attemptId,
      super(const PlacementResultState());

  final PlacementRepository _placement;
  final String _attemptId;

  Future<void> load() async {
    emit(
      state.copyWith(
        view: state.view == PlacementResultView.offline
            ? PlacementResultView.offline
            : PlacementResultView.loading,
        retrying: state.view == PlacementResultView.offline,
        failure: () => null,
      ),
    );
    final result = await _placement.getResult(_attemptId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            view: PlacementResultView.ready,
            result: value,
            levelIndex: value.levelIndex,
            retrying: false,
          ),
        );
      case Err(failure: NetworkFailure()):
        emit(
          state.copyWith(view: PlacementResultView.offline, retrying: false),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            view: PlacementResultView.failed,
            failure: () => failure,
            retrying: false,
          ),
        );
    }
  }

  /// Confirmed on the sheet: one level down, once.
  void lower() {
    if (state.lowerLevel == null) return;
    emit(state.copyWith(levelIndex: state.levelIndex - 1, lowered: true));
  }

  /// «ابدأ من …»: tells the server where to start, then the lessons follow.
  Future<void> accept() async {
    final level = state.level;
    if (level == null || state.accepting || state.accepted) return;
    emit(state.copyWith(accepting: true, actionFailure: () => null));
    final result = await _placement.acceptLevel(_attemptId, level.id);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(accepting: false, accepted: true));
      case Err(:final failure):
        emit(state.copyWith(accepting: false, actionFailure: () => failure));
    }
  }
}
