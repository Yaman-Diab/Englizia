import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_state.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Which grade are you in?": the grades are the levels of the published
/// school-curriculum track, grouped as configured in the control panel.
class GradeCubit extends Cubit<GradeState> {
  GradeCubit(this._tracks) : super(const GradeState());

  final TrackRepository _tracks;

  Future<void> load() async {
    emit(state.copyWith(status: GradeStatus.loading, failure: () => null));
    final result = await _loadLevels();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: GradeStatus.ready,
            groups: groupLevels(value),
            selected: () =>
                value.contains(state.selected) ? state.selected : null,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: GradeStatus.failure, failure: () => failure),
        );
    }
  }

  void select(TrackLevel level) => emit(state.copyWith(selected: () => level));

  Future<Result<List<TrackLevel>>> _loadLevels() async {
    switch (await _tracks.getPublishedTracks()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final school = value
            .where((t) => t.audience == TrackAudience.schoolStudent)
            .toList();
        if (school.isEmpty) return const Err(NotFoundFailure());
        // A grade-selection track first, should several be suggested.
        school.sort(
          (a, b) =>
              (a.entryMethod == TrackEntryMethod.gradeSelection ? 0 : 1) -
              (b.entryMethod == TrackEntryMethod.gradeSelection ? 0 : 1),
        );
        return _tracks.getLevels(school.first.id);
    }
  }

  /// Splits ordered [levels] wherever the display group changes.
  static List<GradeGroup> groupLevels(List<TrackLevel> levels) {
    final groups = <GradeGroup>[];
    for (final level in levels) {
      if (groups.isEmpty || groups.last.title != level.group) {
        groups.add(GradeGroup(title: level.group, levels: [level]));
      } else {
        groups.last.levels.add(level);
      }
    }
    return groups;
  }
}
