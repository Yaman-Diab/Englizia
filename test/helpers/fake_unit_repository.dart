import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/data/datasources/unit_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/unit_plan_model.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/lessons/domain/repositories/unit_repository.dart';

/// The bundled unit's raw JSON, as the mock server sends it.
Map<String, Object?> mockUnitJson(String unitId) => asJsonMap(
  ApiClient.unwrap(
    jsonDecode(File(UnitFakeDataSource.assetOf(unitId)).readAsStringSync()),
  ),
);

UnitPlan mockUnit(String unitId) =>
    UnitPlanModel(mockUnitJson(unitId)).toEntity();

class FakeUnitRepository implements UnitRepository {
  FakeUnitRepository(this.unit);

  UnitPlan unit;
  Failure? failure;
  UnitPlan? kept;
  final seen = <String>{};
  var fetches = 0;

  @override
  UnitPlan? keptUnit(String unitId) => kept;

  @override
  Future<Result<UnitPlan>> getUnit(String unitId) async {
    fetches++;
    if (failure case final failure?) return Err(failure);
    return Ok(unit);
  }

  @override
  bool goalsSeen(String unitId) => seen.contains(unitId);

  @override
  Future<void> setGoalsSeen(String unitId) async => seen.add(unitId);
}
