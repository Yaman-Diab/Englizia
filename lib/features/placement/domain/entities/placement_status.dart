import 'package:equatable/equatable.dart';

/// Where the learner stands with the placement test (requirements v3.0 §12.2).
sealed class PlacementStatus extends Equatable {
  const PlacementStatus();

  @override
  List<Object?> get props => [];
}

/// Never started one.
final class PlacementNotTaken extends PlacementStatus {
  const PlacementNotTaken();
}

/// Stopped at [question] of [stage]; both count from 1.
final class PlacementInProgress extends PlacementStatus {
  const PlacementInProgress({required this.stage, required this.question});

  final int stage;
  final int question;

  @override
  List<Object?> get props => [stage, question];
}

/// Has a result, and may take the test again.
final class PlacementRetakeOpen extends PlacementStatus {
  const PlacementRetakeOpen({required this.level, required this.daysAgo});

  /// The result's CEFR code, e.g. "A2".
  final String level;
  final int daysAgo;

  @override
  List<Object?> get props => [level, daysAgo];
}

/// Has a result, and must wait before taking the test again.
final class PlacementRetakeLocked extends PlacementStatus {
  const PlacementRetakeLocked({required this.daysLeft});

  final int daysLeft;

  @override
  List<Object?> get props => [daysLeft];
}
