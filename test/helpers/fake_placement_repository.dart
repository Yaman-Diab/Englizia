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
  ]);

  final List<Result<PlacementSummary>> results;
  final List<Result<PlacementStatus>> statuses;
  var calls = 0;
  var statusCalls = 0;

  @override
  Future<Result<PlacementSummary>> getSummary() async =>
      results[(calls++).clamp(0, results.length - 1)];

  @override
  Future<Result<PlacementStatus>> getStatus() async =>
      statuses[(statusCalls++).clamp(0, statuses.length - 1)];
}
