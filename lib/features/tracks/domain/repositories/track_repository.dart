import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/entities/track_unit.dart';

abstract interface class TrackRepository {
  /// The tracks onboarding's audiences lead to, in display order; needs no
  /// account.
  Future<Result<List<LearningTrack>>> getOnboardingTracks();

  /// Every published track, in display order; needs a session.
  Future<Result<List<LearningTrack>>> getPublishedTracks();

  /// Published levels of [trackId], in display order; empty for a track
  /// the server doesn't list.
  Future<Result<List<TrackLevel>>> getLevels(String trackId);

  /// Published units of [levelId], in display order.
  Future<Result<List<TrackUnit>>> getUnits(String levelId);
}
