import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';

/// JSON shape of the placement summary; contract in docs/api/placement.md.
// ASSUMPTION(api): field names proposed, not confirmed (docs/api/placement.md).
final class PlacementSummaryModel {
  const PlacementSummaryModel(this.entity);

  factory PlacementSummaryModel.fromJson(Map<String, Object?> json) {
    final minutes = json.readMap('estimatedMinutes');
    final min = minutes?.readInt('min');
    final max = minutes?.readInt('max');
    final stages = json.readInt('stages');
    if (min == null || max == null || stages == null) {
      throw const FormatException('Placement summary is incomplete');
    }
    return PlacementSummaryModel(
      PlacementSummary(
        minMinutes: min,
        maxMinutes: max,
        stages: stages,
        mayAddStage: json.readBool('optionalStage') ?? false,
      ),
    );
  }

  final PlacementSummary entity;
}
