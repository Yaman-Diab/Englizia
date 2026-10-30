import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/models/placement_status_model.dart';
import 'package:englizia/features/placement/data/models/placement_summary_model.dart';
import 'package:englizia/features/placement/data/repositories/placement_repository_impl.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  Future<void> restartTest() => throw UnimplementedError();

  @override
  Future<void> deferTest(String enrollmentId) => throw UnimplementedError();
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

  group('the repository', () {
    late SettingsStorageService settings;
    late FakeHttpAdapter adapter;
    late DateTime now;
    late FakeResponse Function(RequestOptions) answer;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsStorageService(await SharedPreferences.getInstance());
      now = DateTime.utc(2026, 11);
      answer = (_) => const FakeResponse(200);
      adapter = FakeHttpAdapter((options) => answer(options));
    });

    PlacementRepositoryImpl repository() => PlacementRepositoryImpl(
      PlacementRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      ),
      settings: settings,
      now: () => now,
    );

    FakeResponse status(Map<String, Object?> data) =>
        FakeResponse(200, body: {'statusCode': 200, 'data': data});

    void goOffline() => answer = (options) =>
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );

    test('maps errors through the error funnel', () async {
      final result = await PlacementRepositoryImpl(
        _FailingDataSource(),
        settings: settings,
      ).getSummary();
      expect((result as Err).failure, isA<NetworkFailure>());
    });

    test('asks for the status with the session\'s token', () async {
      answer = (_) => status(const {'state': 'none'});
      final result = await repository().getStatus();
      expect(result, const Ok<PlacementStatus>(PlacementNotTaken()));
      expect(adapter.requests.single.path, '/api/v1/app/placement/status');
    });

    test('offline with nothing saved: the failure', () async {
      goOffline();
      final result = await repository().getStatus();
      expect((result as Err).failure, isA<NetworkFailure>());
    });

    test('offline: the saved status, its days brought up to date', () async {
      answer = (_) => status(const {
        'state': 'retakeAvailable',
        'lastLevel': 'A2',
        'daysSinceResult': 34,
      });
      await repository().getStatus();

      goOffline();
      now = now.add(const Duration(days: 3));
      expect(
        await repository().getStatus(),
        const Ok<PlacementStatus>(
          PlacementRetakeOpen(level: 'A2', daysAgo: 37),
        ),
      );
    });

    test('offline: an unfinished test is as it was', () async {
      answer = (_) =>
          status(const {'state': 'inProgress', 'stage': 2, 'question': 4});
      await repository().getStatus();

      goOffline();
      expect(
        await repository().getStatus(),
        const Ok<PlacementStatus>(PlacementInProgress(stage: 2, question: 4)),
      );
    });

    test('offline: a wait counts down, and never says it ran out', () async {
      answer = (_) =>
          status(const {'state': 'retakeLocked', 'daysUntilRetake': 12});
      await repository().getStatus();

      goOffline();
      now = now.add(const Duration(days: 2));
      expect(
        await repository().getStatus(),
        const Ok<PlacementStatus>(PlacementRetakeLocked(daysLeft: 10)),
      );

      now = now.add(const Duration(days: 30));
      expect(
        await repository().getStatus(),
        const Ok<PlacementStatus>(PlacementRetakeLocked(daysLeft: 1)),
      );
    });

    test('a server failure is not hidden by what was saved', () async {
      answer = (_) => status(const {'state': 'none'});
      await repository().getStatus();

      answer = (_) => const FakeResponse(500);
      final result = await repository().getStatus();
      expect((result as Err).failure, isA<ServerFailure>());
    });

    test('a broken saved status counts as none', () async {
      await settings.setPlacementStatus('not json');
      goOffline();
      final result = await repository().getStatus();
      expect((result as Err).failure, isA<NetworkFailure>());
    });

    test('starting over: POST attempts with restart, and forgets', () async {
      answer = (_) =>
          status(const {'state': 'inProgress', 'stage': 1, 'question': 9});
      await repository().getStatus();
      adapter.requests.clear();

      answer = (_) => const FakeResponse(201);
      expect(await repository().restartTest(), isA<Ok<void>>());
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/app/placement/attempts');
      expect(request.data, {'restart': true});
      expect(settings.placementStatus, isNull);
    });

    test('a failed restart keeps what was saved', () async {
      answer = (_) =>
          status(const {'state': 'inProgress', 'stage': 1, 'question': 9});
      await repository().getStatus();

      goOffline();
      expect(await repository().restartTest(), isA<Err<void>>());
      expect(settings.placementStatus, isNotNull);
    });

    test('putting off: PATCH the saved enrollment as deferred', () async {
      answer = (_) => status(const {'state': 'none', 'enrollmentId': 'enr-1'});
      await repository().getStatus();
      adapter.requests.clear();

      answer = (_) => const FakeResponse(200);
      expect(await repository().deferTest(), isA<Ok<void>>());
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/v1/app/enrollments/enr-1');
      expect(request.data, {'placement_state': 'deferred'});
    });

    test('putting off with nothing saved asks for the enrollment', () async {
      answer = (options) => options.method == 'GET'
          ? status(const {'state': 'none', 'enrollmentId': 'enr-2'})
          : const FakeResponse(200);
      expect(await repository().deferTest(), isA<Ok<void>>());
      expect(adapter.requests.last.path, '/api/v1/app/enrollments/enr-2');
    });

    test('with no enrollment to change, putting off fails', () async {
      answer = (_) => status(const {'state': 'none'});
      final result = await repository().deferTest();
      expect((result as Err).failure, isA<UnknownFailure>());
    });

    test('mock mode answers the two actions', () async {
      final fake = PlacementFakeDataSource(
        _DiskBundle(),
        latency: Duration.zero,
      );
      await fake.restartTest();
      await fake.deferTest('enr');
      expect((await fake.getStatus()).enrollmentId, 'enr_general');
    });
  });
}
