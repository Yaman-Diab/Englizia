import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';

abstract interface class PlacementRepository {
  /// The published placement test, as introduced to the learner.
  Future<Result<PlacementSummary>> getSummary();
}
