import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/tracks/data/datasources/track_remote_data_source.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/entities/track_unit.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';

final class TrackRepositoryImpl implements TrackRepository {
  const TrackRepositoryImpl(this._remote);

  final TrackRemoteDataSource _remote;

  @override
  Future<Result<List<LearningTrack>>> getPublishedTracks() => guard(() async {
    final models = await _remote.getPublishedTracks();
    return [for (final model in models) model.entity]
      ..sort((a, b) => a.order.compareTo(b.order));
  });

  @override
  Future<Result<List<TrackLevel>>> getLevels(String trackId) => guard(() async {
    final models = await _remote.getLevels(trackId);
    return [for (final model in models) model.entity]
      ..sort((a, b) => a.order.compareTo(b.order));
  });

  @override
  Future<Result<List<TrackUnit>>> getUnits(String levelId) => guard(() async {
    final models = await _remote.getUnits(levelId);
    return [for (final model in models) model.entity]
      ..sort((a, b) => a.order.compareTo(b.order));
  });
}
