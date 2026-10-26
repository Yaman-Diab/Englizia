import 'package:englizia/core/error/failure.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:equatable/equatable.dart';

enum AudienceStatus { loading, ready, failure }

final class AudienceState extends Equatable {
  const AudienceState({
    this.status = AudienceStatus.loading,
    this.available = const {},
    this.selected,
    this.failure,
  });

  final AudienceStatus status;

  /// Audiences with at least one published track; the others are «قريبًا».
  final Set<TrackAudience> available;

  /// No default: the learner must choose (requirements v3.0 §4.2).
  final TrackAudience? selected;
  final Failure? failure;

  bool get canContinue => status == AudienceStatus.ready && selected != null;

  /// Nullable fields take a function so they can be cleared: `selected: () => null`.
  AudienceState copyWith({
    AudienceStatus? status,
    Set<TrackAudience>? available,
    TrackAudience? Function()? selected,
    Failure? Function()? failure,
  }) => AudienceState(
    status: status ?? this.status,
    available: available ?? this.available,
    selected: selected != null ? selected() : this.selected,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, available, selected, failure];
}
