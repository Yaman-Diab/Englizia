import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/tracks/data/datasources/track_remote_data_source.dart';
import 'package:englizia/features/tracks/data/models/track_model.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/entities/track_unit.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';

final class TrackRepositoryImpl implements TrackRepository {
  TrackRepositoryImpl(this._remote);

  final TrackRemoteDataSource _remote;

  /// Levels arrive inside their track; kept by track id from every list
  /// fetched, so a later step doesn't fetch them again.
  final _levels = <String, List<TrackLevel>>{};

  @override
  Future<Result<List<LearningTrack>>> getOnboardingTracks() =>
      guard(() async => _kept(await _remote.getOnboardingTracks()));

  @override
  Future<Result<List<LearningTrack>>> getPublishedTracks() =>
      guard(() async => _kept(await _remote.getCatalog()));

  /// Onboarding's list first, as it needs no session; then the catalog,
  /// which has the tracks no audience leads to.
  @override
  Future<Result<List<TrackLevel>>> getLevels(String trackId) => guard(() async {
    if (_levels[trackId] case final levels?) return levels;
    _kept(await _remote.getOnboardingTracks());
    if (_levels[trackId] case final levels?) return levels;
    _kept(await _remote.getCatalog());
    return _levels[trackId] ?? const [];
  });

  @override
  Future<Result<List<TrackUnit>>> getUnits(String levelId) => guard(() async {
    final models = await _remote.getUnits(levelId);
    return [for (final model in models) model.entity]
      ..sort((a, b) => a.order.compareTo(b.order));
  });

  List<LearningTrack> _kept(List<TrackModel> models) {
    for (final model in models) {
      _levels[model.entity.id] = model.levels;
    }
    return [for (final model in models) model.entity]
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}
