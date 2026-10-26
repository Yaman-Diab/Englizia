import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:equatable/equatable.dart';

enum GradeStatus { loading, ready, failure }

/// Consecutive levels that share a display group ("الحلقة الأولى").
final class GradeGroup extends Equatable {
  const GradeGroup({required this.title, required this.levels});

  /// Null when the panel gave these levels no group.
  final LocalizedText? title;
  final List<TrackLevel> levels;

  @override
  List<Object?> get props => [title, levels];
}

final class GradeState extends Equatable {
  const GradeState({
    this.status = GradeStatus.loading,
    this.groups = const [],
    this.selected,
    this.failure,
  });

  final GradeStatus status;
  final List<GradeGroup> groups;
  final TrackLevel? selected;
  final Failure? failure;

  bool get canContinue => status == GradeStatus.ready && selected != null;

  /// Nullable fields take a function so they can be cleared: `selected: () => null`.
  GradeState copyWith({
    GradeStatus? status,
    List<GradeGroup>? groups,
    TrackLevel? Function()? selected,
    Failure? Function()? failure,
  }) => GradeState(
    status: status ?? this.status,
    groups: groups ?? this.groups,
    selected: selected != null ? selected() : this.selected,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, groups, selected, failure];
}
