import 'dart:convert';
import 'dart:math';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/models/placement_status_model.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';

final class PlacementRepositoryImpl implements PlacementRepository {
  const PlacementRepositoryImpl(
    this._remote, {
    required SettingsStorageService settings,
    DateTime Function() now = DateTime.now,
  }) : _settings = settings,
       _now = now;

  final PlacementRemoteDataSource _remote;
  final SettingsStorageService _settings;
  final DateTime Function() _now;

  @override
  Future<Result<PlacementSummary>> getSummary() =>
      guard(() async => (await _remote.getSummary()).entity);

  @override
  Future<Result<PlacementStatus>> getStatus() async {
    final result = await guard(() async {
      final status = await _remote.getStatus();
      await _save(status);
      return status.entity;
    });
    if (result case Err(failure: NetworkFailure())) {
      if (_savedStatus() case final saved?) return Ok(saved);
    }
    return result;
  }

  @override
  Future<Result<void>> restartTest() => guard(() async {
    await _remote.restartTest();
    // The saved status still names the question left behind.
    await _settings.clearPlacementStatus();
  });

  @override
  Future<Result<void>> deferTest() => guard(() async {
    final id =
        _savedModel()?.$1.enrollmentId ??
        (await _remote.getStatus()).enrollmentId;
    if (id == null) {
      throw const FormatException('Placement status has no enrollment id');
    }
    await _remote.deferTest(id);
  });

  /// Keeps [status] for when there is no connection. Not kept costs only that.
  Future<void> _save(PlacementStatusModel status) async {
    try {
      await _settings.setPlacementStatus(
        jsonEncode({
          _savedAtKey: _now().toUtc().toIso8601String(),
          _statusKey: status.json,
        }),
      );
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saving the placement status failed');
    }
  }

  /// The saved status and when it was saved; null with none, or a broken one.
  (PlacementStatusModel, DateTime)? _savedModel() {
    final saved = _settings.placementStatus;
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved) as Map<String, Object?>;
      return (
        PlacementStatusModel.fromJson(
          json[_statusKey]! as Map<String, Object?>,
        ),
        DateTime.parse(json[_savedAtKey]! as String),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saved placement status unreadable');
      return null;
    }
  }

  /// The saved status as it reads today. A wait that ran out while offline
  /// still says a day: only the server can say the test is open again.
  PlacementStatus? _savedStatus() {
    final saved = _savedModel();
    if (saved == null) return null;
    final (model, savedAt) = saved;
    final passed = max(0, _now().difference(savedAt).inDays);
    return switch (model.entity) {
      PlacementRetakeOpen(:final level, :final daysAgo) => PlacementRetakeOpen(
        level: level,
        daysAgo: daysAgo + passed,
      ),
      PlacementRetakeLocked(:final daysLeft) => PlacementRetakeLocked(
        daysLeft: max(1, daysLeft - passed),
      ),
      final status => status,
    };
  }

  static const _savedAtKey = 'savedAt';
  static const _statusKey = 'status';
}
