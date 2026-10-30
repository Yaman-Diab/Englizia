import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/placement/data/models/placement_status_model.dart';
import 'package:englizia/features/placement/data/models/placement_summary_model.dart';
import 'package:flutter/services.dart';

abstract interface class PlacementRemoteDataSource {
  Future<PlacementSummaryModel> getSummary();

  Future<PlacementStatusModel> getStatus();

  Future<void> restartTest();

  Future<void> deferTest(String enrollmentId);
}

final class PlacementRemoteDataSourceImpl implements PlacementRemoteDataSource {
  const PlacementRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<PlacementSummaryModel> getSummary() async =>
      PlacementSummaryModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.placementSummary)),
      );

  @override
  Future<PlacementStatusModel> getStatus() async =>
      PlacementStatusModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.placementStatus)),
      );

  @override
  Future<void> restartTest() =>
      _client.post(ApiEndpoints.placementAttempts, data: {'restart': true});

  @override
  Future<void> deferTest(String enrollmentId) => _client.patch(
    ApiEndpoints.enrollment(enrollmentId),
    data: {'placement_state': 'deferred'},
  );
}

/// Mock mode (`env/mock.json`): the contract's examples from the bundled
/// assets the tests also use. Each opening of the test's intro shows the next
/// status, so all of them can be seen. Deleted once the endpoints are confirmed.
final class PlacementFakeDataSource implements PlacementRemoteDataSource {
  PlacementFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
  });

  static const asset = 'assets/mock/placement/summary.json';
  static const statusAssets = [
    'assets/mock/placement/status_none.json',
    'assets/mock/placement/status_in_progress.json',
    'assets/mock/placement/status_retake_available.json',
    'assets/mock/placement/status_retake_locked.json',
  ];

  final AssetBundle _bundle;
  final Duration latency;
  var _opened = 0;

  @override
  Future<PlacementSummaryModel> getSummary() async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return PlacementSummaryModel.fromJson(asJsonMap(ApiClient.unwrap(body)));
  }

  @override
  Future<PlacementStatusModel> getStatus() async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(
      await _bundle.loadString(statusAssets[_opened++ % statusAssets.length]),
    );
    return PlacementStatusModel.fromJson(asJsonMap(ApiClient.unwrap(body)));
  }

  @override
  Future<void> restartTest() => Future<void>.delayed(latency);

  @override
  Future<void> deferTest(String enrollmentId) => Future<void>.delayed(latency);
}
