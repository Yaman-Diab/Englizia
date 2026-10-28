import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/tracks/domain/entities/track_unit.dart';

/// JSON shape of a unit; contract in docs/api/tracks.md.
// ASSUMPTION(api): field names proposed, not confirmed (docs/api/tracks.md).
final class TrackUnitModel {
  const TrackUnitModel(this.entity);

  factory TrackUnitModel.fromJson(Map<String, Object?> json) {
    final id = json.readString('id');
    if (id == null) throw const FormatException('Unit without an id');
    return TrackUnitModel(
      TrackUnit(
        id: id,
        order: json.readInt('order') ?? 0,
        title: json.readString('title') ?? '',
        topic: json.readText('topic'),
      ),
    );
  }

  final TrackUnit entity;
}
