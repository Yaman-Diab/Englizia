import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:equatable/equatable.dart';

final class AudienceState extends Equatable {
  const AudienceState({
    this.status = LoadStatus.loading,
    this.tracks = const [],
    this.selected,
    this.failure,
  });

  final LoadStatus status;

  /// Published tracks, in display order.
  final List<LearningTrack> tracks;

  /// No default: the learner must choose (requirements v3.0 §4.2).
  final TrackAudience? selected;
  final Failure? failure;

  /// Audiences with at least one published track; the others are «قريبًا».
  Set<TrackAudience> get available => {for (final t in tracks) ?t.audience};

  /// Where the choice leads: the first track (by display order) suggested
  /// for the chosen audience, with its entry method.
  OnboardingPath? get path {
    final audience = selected;
    if (audience == null) return null;
    for (final track in tracks) {
      if (track.audience == audience) return OnboardingPath.forTrack(track);
    }
    return null;
  }

  bool get canContinue => status == LoadStatus.ready && path != null;

  /// Nullable fields take a function so they can be cleared: `selected: () => null`.
  AudienceState copyWith({
    LoadStatus? status,
    List<LearningTrack>? tracks,
    TrackAudience? Function()? selected,
    Failure? Function()? failure,
  }) => AudienceState(
    status: status ?? this.status,
    tracks: tracks ?? this.tracks,
    selected: selected != null ? selected() : this.selected,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, tracks, selected, failure];
}
