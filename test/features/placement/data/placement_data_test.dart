import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/models/placement_status_model.dart';
import 'package:englizia/features/placement/data/models/placement_summary_model.dart';
import 'package:englizia/features/placement/data/repositories/placement_repository_impl.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';

/// The contract's example response: the same file mock mode serves.
final exampleBody =
    jsonDecode(File(PlacementFakeDataSource.asset).readAsStringSync())
        as Map<String, Object?>;

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _FailingDataSource implements PlacementRemoteDataSource {
  @override
  Future<PlacementSummaryModel> getSummary() async =>
      throw const NetworkException('connectionError');

  @override
  Future<PlacementStatusModel> getStatus() => throw UnimplementedError();
}

void main() {
  const expected = PlacementSummary(
    minMinutes: 12,
    maxMinutes: 15,
    stages: 2,
    mayAddStage: true,
  );

  test('the example response parses', () {
    expect(
      PlacementSummaryModel.fromJson(
        asJsonMap(ApiClient.unwrap(exampleBody)),
      ).entity,
      expected,
    );
  });

  test('an incomplete summary is rejected', () {
    expect(
      () => PlacementSummaryModel.fromJson(const {'stages': 2}),
      throwsFormatException,
    );
  });

  test('a missing optional stage means none', () {
    final summary = PlacementSummaryModel.fromJson(const {
      'estimatedMinutes': {'min': 8, 'max': 10},
      'stages': 2,
    }).entity;
    expect(summary.mayAddStage, isFalse);
  });

  test('GET /api/v1/app/placement/summary', () async {
    final adapter = FakeHttpAdapter(
      (_) => FakeResponse(200, body: exampleBody),
    );
    final client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

    final summary = await PlacementRemoteDataSourceImpl(client).getSummary();

    expect(adapter.requests.single.path, '/api/v1/app/placement/summary');
    expect(summary.entity, expected);
  });

  test('mock mode serves the bundled example', () async {
    final summary = await PlacementFakeDataSource(
      _DiskBundle(),
      latency: Duration.zero,
    ).getSummary();
    expect(summary.entity, expected);
  });

  group('status', () {
    test('every state of the contract parses from the mock files', () async {
      final source = PlacementFakeDataSource(
        _DiskBundle(),
        latency: Duration.zero,
      );
      final seen = [
        for (final _ in PlacementFakeDataSource.statusAssets)
          (await source.getStatus()).entity,
      ];
      expect(seen, const [
        PlacementNotTaken(),
        PlacementInProgress(stage: 1, question: 9),
        PlacementRetakeOpen(level: 'A2', daysAgo: 34),
        PlacementRetakeLocked(daysLeft: 12),
      ]);
      // Then it starts over, to walk through them again.
      expect((await source.getStatus()).entity, const PlacementNotTaken());
    });

    test('a state this version does not know reads as not taken', () {
      expect(
        PlacementStatusModel.fromJson(const {'state': 'somethingNew'}).entity,
        const PlacementNotTaken(),
      );
    });

    test('a state with missing fields is rejected', () {
      expect(
        () => PlacementStatusModel.fromJson(const {'state': 'retakeLocked'}),
        throwsFormatException,
      );
    });
  });

  test('the repository maps errors through the error funnel', () async {
    final result = await PlacementRepositoryImpl(
      _FailingDataSource(),
    ).getSummary();
    expect((result as Err).failure, isA<NetworkFailure>());
  });
}
