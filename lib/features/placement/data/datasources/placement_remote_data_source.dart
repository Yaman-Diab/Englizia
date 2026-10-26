import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/placement/data/models/placement_summary_model.dart';
import 'package:flutter/services.dart';

abstract interface class PlacementRemoteDataSource {
  Future<PlacementSummaryModel> getSummary();
}

final class PlacementRemoteDataSourceImpl implements PlacementRemoteDataSource {
  const PlacementRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<PlacementSummaryModel> getSummary() async =>
      PlacementSummaryModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.placementSummary)),
      );
}

/// Mock mode (`env/mock.json`): the contract's example from the bundled
/// asset the tests also use. Deleted once the endpoint is confirmed.
final class PlacementFakeDataSource implements PlacementRemoteDataSource {
  const PlacementFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
  });

  static const asset = 'assets/mock/placement/summary.json';

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<PlacementSummaryModel> getSummary() async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return PlacementSummaryModel.fromJson(asJsonMap(ApiClient.unwrap(body)));
  }
}
