import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/server_unit.dart';
import 'package:englizia/features/lessons/data/models/unit_plan_model.dart';
import 'package:englizia/features/tracks/data/datasources/enrollments_reader.dart';
import 'package:flutter/services.dart';

abstract interface class UnitRemoteDataSource {
  Future<UnitPlanModel> getUnit(String unitId);
}

/// The server has no call for one unit: it is read from its level's map
/// (`GET /app/enrollments/{trackId}/map`, docs/api/home.md).
final class UnitRemoteDataSourceImpl implements UnitRemoteDataSource {
  UnitRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  /// The track whose map held the last unit, so the next is found without
  /// asking again which track is in use.
  String? _trackId;

  @override
  Future<UnitPlanModel> getUnit(String unitId) async {
    final last = _trackId;
    if (last != null) {
      try {
        if (await _unitOf(last, unitId) case final unit?) return unit;
      } on ApiException catch (error) {
        // No longer joined: the active track is asked for below.
        if (error.statusCode != ApiStatusCodes.notFound) rethrow;
      }
    }
    final active = await EnrollmentsReader(_client).activeTrackId();
    final unit = active == null || active == last
        ? null
        : await _unitOf(active, unitId);
    if (unit == null) {
      throw const ApiException(statusCode: ApiStatusCodes.notFound);
    }
    _trackId = active;
    return unit;
  }

  Future<UnitPlanModel?> _unitOf(String trackId, String unitId) async {
    final map = asJsonMap(await _client.get(ApiEndpoints.levelMap(trackId)));
    final unit = unitFromMap(map, unitId);
    return unit == null ? null : UnitPlanModel(unit);
  }
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
