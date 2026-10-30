import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';

/// JSON shape of the learner's placement status; contract in
/// docs/api/placement.md.
// ASSUMPTION(api): field names proposed, not confirmed (docs/api/placement.md).
final class PlacementStatusModel {
  const PlacementStatusModel(this.entity, {required this.json});

  factory PlacementStatusModel.fromJson(Map<String, Object?> json) =>
      PlacementStatusModel(json: json, switch (json.readString('state')) {
        'inProgress' => PlacementInProgress(
          stage: _require(json.readInt('stage')),
          question: _require(json.readInt('question')),
        ),
        'retakeAvailable' => PlacementRetakeOpen(
          level: _require(json.readString('lastLevel')),
          daysAgo: _require(json.readInt('daysSinceResult')),
        ),
        'retakeLocked' => PlacementRetakeLocked(
          daysLeft: _require(json.readInt('daysUntilRetake')),
        ),
        // A state this version doesn't know: the server still decides what
        // starting the test means.
        _ => const PlacementNotTaken(),
      });

  static T _require<T>(T? value) =>
      value ?? (throw const FormatException('Placement status is incomplete'));

  final PlacementStatus entity;

  /// As received, to keep on the phone.
  final Map<String, Object?> json;

  /// The learner's enrollment in the track, which putting the test off changes.
  String? get enrollmentId => json.readString('enrollmentId');
}
