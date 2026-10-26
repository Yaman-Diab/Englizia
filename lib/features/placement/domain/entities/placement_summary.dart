import 'package:equatable/equatable.dart';

/// What the learner is told about the published placement test before
/// taking it (requirements v3.0 §12.2; server doc §12.5).
final class PlacementSummary extends Equatable {
  const PlacementSummary({
    required this.minMinutes,
    required this.maxMinutes,
    required this.stages,
    required this.mayAddStage,
  });

  /// Estimated duration, computed by the server from the question count.
  final int minMinutes;
  final int maxMinutes;

  /// Stages every learner takes (routing, then a block).
  final int stages;

  /// Whether a short deciding stage may be added at a boundary.
  final bool mayAddStage;

  @override
  List<Object?> get props => [minMinutes, maxMinutes, stages, mayAddStage];
}
