import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/english_level_choice.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:equatable/equatable.dart';

final class LevelState extends Equatable {
  const LevelState({
    this.status = LoadStatus.loading,
    this.choice,
    this.summary,
    this.firstLevel,
    this.failure,
    this.online = true,
  });

  final LoadStatus status;
  final EnglishLevelChoice? choice;

  /// The published test's duration and stages; null until loaded, or when
  /// no test is published.
  final PlacementSummary? summary;

  /// Where a learner who skips the test starts. Null until loaded, or when
  /// the path names no track.
  final TrackLevel? firstLevel;
  final Failure? failure;

  /// The test needs a connection; starting from the beginning does not.
  final bool online;

  /// No published test version: the test is hidden, the first level stays.
  bool get testUnavailable => failure is NotFoundFailure;

  bool get canTakeTest =>
      choice == EnglishLevelChoice.some && online && !testUnavailable;

  /// Nullable fields take a function so they can be cleared: `choice: () => null`.
  LevelState copyWith({
    LoadStatus? status,
    EnglishLevelChoice? Function()? choice,
    PlacementSummary? Function()? summary,
    TrackLevel? Function()? firstLevel,
    Failure? Function()? failure,
    bool? online,
  }) => LevelState(
    status: status ?? this.status,
    choice: choice != null ? choice() : this.choice,
    summary: summary != null ? summary() : this.summary,
    firstLevel: firstLevel != null ? firstLevel() : this.firstLevel,
    failure: failure != null ? failure() : this.failure,
    online: online ?? this.online,
  );

  @override
  List<Object?> get props => [
    status,
    choice,
    summary,
    firstLevel,
    failure,
    online,
  ];
}
