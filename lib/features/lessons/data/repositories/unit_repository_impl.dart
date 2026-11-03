import 'dart:convert';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/unit_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/unit_plan_model.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/lessons/domain/repositories/unit_repository.dart';

final class UnitRepositoryImpl implements UnitRepository {
  UnitRepositoryImpl(this._remote, {required SettingsStorageService settings})
    : _settings = settings;

  final UnitRemoteDataSource _remote;
  final SettingsStorageService _settings;

  /// Units kept to open offline: small enough for preferences (ADR 12).
  static const _keptUnits = 6;

  @override
  UnitPlan? keptUnit(String unitId) {
    final json = _kept()[unitId];
    if (json == null) return null;
    try {
      return UnitPlanModel(asJsonMap(json)).toEntity();
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Kept unit unreadable');
      return null;
    }
  }

  @override
  Future<Result<UnitPlan>> getUnit(String unitId) async {
    final fetched = await guard(() async {
      final model = await _remote.getUnit(unitId);
      final unit = model.toEntity();
      await _keep(unitId, model.json);
      return unit;
    });
    return switch (fetched) {
      Err(failure: NetworkFailure()) => switch (keptUnit(unitId)) {
        final kept? => Ok(kept),
        null => fetched,
      },
      _ => fetched,
    };
  }

  Map<String, Object?> _kept() {
    final saved = _settings.units;
    if (saved == null) return {};
    try {
      return asJsonMap(jsonDecode(saved));
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Kept units unreadable');
      return {};
    }
  }

  /// Newest last; the oldest go first.
  Future<void> _keep(String unitId, Map<String, Object?> json) async {
    final kept = _kept()
      ..remove(unitId)
      ..[unitId] = json;
    final over = kept.length - _keptUnits;
    if (over > 0) kept.keys.take(over).toList().forEach(kept.remove);
    try {
      await _settings.setUnits(jsonEncode(kept));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Keeping the unit failed');
    }
  }

  @override
  bool goalsSeen(String unitId) => _settings.unitsSeen.contains(unitId);

  @override
  Future<void> setGoalsSeen(String unitId) async {
    if (goalsSeen(unitId)) return;
    try {
      await _settings.setUnitsSeen([..._settings.unitsSeen, unitId]);
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Keeping the unit seen failed');
    }
  }
}
