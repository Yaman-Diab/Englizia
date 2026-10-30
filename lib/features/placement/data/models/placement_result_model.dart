import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';

/// JSON shape of the result; contract in docs/api/placement.md.
// ASSUMPTION(api): field names proposed, not confirmed (docs/api/placement.md).
final class PlacementResultModel {
  const PlacementResultModel(this.entity);

  factory PlacementResultModel.fromJson(Map<String, Object?> json) {
    final levels = [
      for (final level in json.readList('levels') ?? const <Object?>[])
        _level(asJsonMap(level)),
    ];
    final measured = json.readString('levelId');
    final index = levels.indexWhere((level) => level.id == measured);
    if (index < 0) {
      throw const FormatException(
        'Placement result: no level among the levels',
      );
    }
    return PlacementResultModel(
      PlacementResult(
        levels: levels,
        levelIndex: index,
        skills: [
          for (final skill in json.readList('skills') ?? const <Object?>[])
            ?_skill(asJsonMap(skill)),
        ],
      ),
    );
  }

  static PlacementLevel _level(Map<String, Object?> json) {
    final id = json.readString('id');
    final code = json.readString('code');
    final name = json.readText('name');
    if (id == null || code == null || name == null) {
      throw const FormatException('Placement result: an incomplete level');
    }
    return PlacementLevel(
      id: id,
      code: code,
      name: name,
      canDo: [
        for (final line in json.readList('canDo') ?? const <Object?>[])
          ?{'line': line}.readText('line'),
      ],
    );
  }

  /// Null for a skill this version doesn't know: the others still show.
  static PlacementSkill? _skill(Map<String, Object?> json) {
    final kind = PlacementSkillKind.values
        .asNameMap()[json.readString('skill')];
    final score = json['score'];
    if (kind == null || score is! num) return null;
    return PlacementSkill(kind: kind, score: score.toDouble());
  }

  final PlacementResult entity;
}
