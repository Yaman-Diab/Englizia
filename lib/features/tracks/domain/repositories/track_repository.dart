import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/entities/track_unit.dart';

abstract interface class TrackRepository {
  /// Published tracks only, in display order.
  Future<Result<List<LearningTrack>>> getPublishedTracks();

  /// Published levels of [trackId], in display order.
  Future<Result<List<TrackLevel>>> getLevels(String trackId);

  /// Published units of [levelId], in display order.
  Future<Result<List<TrackUnit>>> getUnits(String levelId);
}
