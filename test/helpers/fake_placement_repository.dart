import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';

const testPlacementSummary = PlacementSummary(
  minMinutes: 12,
  maxMinutes: 15,
  stages: 2,
  mayAddStage: true,
);

/// Serves queued results in order, repeating the last one.
class FakePlacementRepository implements PlacementRepository {
  FakePlacementRepository([
    this.results = const [Ok(testPlacementSummary)],
    this.statuses = const [Ok(PlacementNotTaken())],
    this.actions = const [Ok(null)],
  ]);

  final List<Result<PlacementSummary>> results;
  final List<Result<PlacementStatus>> statuses;

  /// What restarting and putting off answer, one after another.
  final List<Result<void>> actions;
  var calls = 0;
  var statusCalls = 0;
  var restarts = 0;
  var defers = 0;

  @override
  Future<Result<PlacementSummary>> getSummary() async =>
      results[(calls++).clamp(0, results.length - 1)];

  @override
  Future<Result<PlacementStatus>> getStatus() async =>
      statuses[(statusCalls++).clamp(0, statuses.length - 1)];

  @override
  Future<Result<void>> restartTest() async {
    restarts++;
    return _action();
  }

  @override
  Future<Result<void>> deferTest() async {
    defers++;
    return _action();
  }

  Result<void> _action() =>
      actions[(restarts + defers - 1).clamp(0, actions.length - 1)];
}
