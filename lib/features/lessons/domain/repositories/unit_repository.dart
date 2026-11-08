import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';

abstract interface class UnitRepository {
  /// The unit as last seen on this phone, to show at once.
  UnitPlan? keptUnit(String unitId);

  /// The unit from the server, kept for offline; offline, the kept one.
  Future<Result<UnitPlan>> getUnit(String unitId);

  /// «ستتعلّم أن…» opens on the first visit only.
  bool goalsSeen(String unitId);

  Future<void> setGoalsSeen(String unitId);
}
