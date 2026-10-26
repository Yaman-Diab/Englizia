import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';

abstract interface class TrackRepository {
  /// Published tracks only, in display order.
  Future<Result<List<LearningTrack>>> getPublishedTracks();
}
