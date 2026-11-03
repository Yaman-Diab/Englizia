import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/unit_plan_model.dart';
import 'package:flutter/services.dart';

abstract interface class UnitRemoteDataSource {
  Future<UnitPlanModel> getUnit(String unitId);
}

final class UnitRemoteDataSourceImpl implements UnitRemoteDataSource {
  const UnitRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<UnitPlanModel> getUnit(String unitId) async =>
      UnitPlanModel(asJsonMap(await _client.get(ApiEndpoints.unit(unitId))));
}

/// Mock mode (`env/mock.json`): the bundled units, one of each kind the
/// design shows. Deleted once the endpoint is confirmed.
final class UnitFakeDataSource implements UnitRemoteDataSource {
  UnitFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 600),
  });

  static const farm = 'unit_gen_a2_03';
  static const market = 'unit_gen_a2_04';
  static const emar = 'unit_emar_07_03';
  static const kids = 'unit_kids_s2_02';
  static const units = [farm, market, emar, kids];

  static String assetOf(String unitId) => 'assets/mock/units/$unitId.json';

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<UnitPlanModel> getUnit(String unitId) async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(
      await _bundle.loadString(assetOf(units.contains(unitId) ? unitId : farm)),
    );
    return UnitPlanModel(asJsonMap(ApiClient.unwrap(body)));
  }
}
