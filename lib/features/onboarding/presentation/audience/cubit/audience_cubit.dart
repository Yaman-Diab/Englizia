import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_state.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Who will learn": which choices exist is decided by the published tracks
/// and their "suggested for" setting in the control panel.
class AudienceCubit extends Cubit<AudienceState> {
  AudienceCubit(this._tracks) : super(const AudienceState());

  final TrackRepository _tracks;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    final result = await _tracks.getPublishedTracks();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final available = {for (final track in value) ?track.audience};
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            tracks: value,
            // A choice whose track was hidden meanwhile is dropped.
            selected: () =>
                available.contains(state.selected) ? state.selected : null,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: LoadStatus.failure, failure: () => failure),
        );
    }
  }

  void select(TrackAudience audience) {
    if (!state.available.contains(audience)) return;
    emit(state.copyWith(selected: () => audience));
  }
}
