import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';

final class PlacementRepositoryImpl implements PlacementRepository {
  const PlacementRepositoryImpl(this._remote);

  final PlacementRemoteDataSource _remote;

  @override
  Future<Result<PlacementSummary>> getSummary() =>
      guard(() async => (await _remote.getSummary()).entity);

  @override
  Future<Result<PlacementStatus>> getStatus() =>
      guard(() async => (await _remote.getStatus()).entity);
}
