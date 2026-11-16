import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/auth_interceptor.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/tracks/data/datasources/track_remote_data_source.dart';
import 'package:englizia/features/tracks/data/models/track_model.dart';
import 'package:englizia/features/tracks/data/models/track_unit_model.dart';
import 'package:englizia/features/tracks/data/repositories/track_repository_impl.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';

/// Mock mode's examples, in the server's shape.
Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

final configBody = _read(TrackFakeDataSource.configAsset);
final catalogBody = _read(TrackFakeDataSource.catalogAsset);

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _FailingDataSource implements TrackRemoteDataSource {
  @override
  Future<List<TrackModel>> getOnboardingTracks() async =>
      throw const NetworkException('connectionError');

  @override
  Future<List<TrackModel>> getCatalog() async =>
      throw const NetworkException('connectionError');

  @override
  Future<List<TrackUnitModel>> getUnits(String levelId) async =>
      throw const NetworkException('connectionError');
}

class _FixedDataSource implements TrackRemoteDataSource {
  _FixedDataSource({
    this.onboarding = const [],
    this.catalog = const [],
    this.units = const [],
  });

  final List<TrackModel> onboarding;
  final List<TrackModel> catalog;
  final List<TrackUnitModel> units;
  var onboardingCalls = 0;
  var catalogCalls = 0;

  @override
  Future<List<TrackModel>> getOnboardingTracks() async {
    onboardingCalls++;
    return onboarding;
  }

  @override
  Future<List<TrackModel>> getCatalog() async {
    catalogCalls++;
    return catalog;
  }

  @override
  Future<List<TrackUnitModel>> getUnits(String levelId) async => units;
}

ApiClient _client(FakeHttpAdapter adapter) => ApiClient(
  Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter,
);

void main() {
  group('onboarding: system/config', () {
    test('the tracks come by audience, each with its levels', () {
      final tracks = parseOnboarding(ApiClient.unwrap(configBody));

      expect(tracks.map((t) => t.entity.id), [
        'trk_general',
        'trk_kids',
        'trk_emar',
      ]);
      final general = tracks.first.entity;
      expect(
        general.title,
        const LocalizedText(ar: 'الإنجليزية العامة', en: 'General English'),
      );
      expect(general.audience, TrackAudience.self);
      expect(general.entryMethod, TrackEntryMethod.placementTest);
      expect(tracks[1].entity.audience, TrackAudience.child);
      expect(tracks[1].levels.every((l) => l.kidsMode), isTrue);
      final emar = tracks.last;
      expect(emar.entity.audience, TrackAudience.schoolStudent);
      expect(emar.entity.entryMethod, TrackEntryMethod.gradeSelection);
      expect(emar.levels, hasLength(12));
      final seventh = emar.levels[6];
      expect((seventh.order, seventh.schoolGrade), (7, 7));
      expect(seventh.name.of('ar'), 'السابع');
      expect(seventh.group?.of('ar'), 'الحلقة الثانية');
    });

    test('the dev server answer: every audience, no track yet', () {
      expect(
        parseOnboarding(ApiClient.unwrap(apiFixture('app_system_config'))),
        isEmpty,
      );
    });

    test('an audience the app does not know suggests nothing', () {
      final tracks = parseOnboarding({
        'onboarding': [
          {
            'audience': 'teachers',
            'tracks': [
              {'id': 't'},
            ],
          },
        ],
      });
      expect(tracks.single.entity.audience, isNull);
    });

    test('without the onboarding list it is rejected', () {
      expect(() => parseOnboarding(const {}), throwsFormatException);
    });

    test('GET /api/v1/app/system/config, without a session', () async {
      final adapter = FakeHttpAdapter(
        (_) => FakeResponse(200, body: configBody),
      );
      final tracks = await TrackRemoteDataSourceImpl(
        _client(adapter),
      ).getOnboardingTracks();

      final request = adapter.requests.single;
      expect(request.path, '/api/v1/app/system/config');
      expect(request.extra[AuthInterceptor.skipAuthKey], isTrue);
      expect(tracks, hasLength(3));
    });
  });

  group('the catalog: /app/tracks', () {
    test('the tracks under items, with descriptions', () {
      final tracks = parseCatalog(ApiClient.unwrap(catalogBody));
      expect(tracks, hasLength(3));
      expect(
        tracks.first.entity.description.of('en'),
        'From zero to B2, with a placement test',
      );
      expect(tracks.last.entity.audience, TrackAudience.schoolStudent);
    });

    test('the dev server answer: no track yet', () {
      expect(
        parseCatalog(ApiClient.unwrap(apiFixture('app_tracks_empty'))),
        isEmpty,
      );
    });

    test('GET /api/v1/app/tracks', () async {
      final adapter = FakeHttpAdapter(
        (_) => FakeResponse(200, body: catalogBody),
      );
      await TrackRemoteDataSourceImpl(_client(adapter)).getCatalog();
      expect(adapter.requests.single.path, '/api/v1/app/tracks');
    });
  });

  group('TrackModel', () {
    test('English falls back to Arabic; a broken level is skipped', () {
      final model = TrackModel.fromJson(const {
        'id': 't',
        'nameAr': 'مسار',
        'levels': [
          {'id': 'l1', 'nameAr': 'الأول'},
          'not a level',
          {'nameAr': 'no id'},
        ],
      }, order: 0);
      expect(model.entity.title.of('en'), 'مسار');
      final level = model.levels.single;
      expect(level.name.of('en'), 'الأول');
      expect((level.group, level.schoolGrade), (null, null));
    });

    test('an unknown entry mode is a direct start', () {
      final model = TrackModel.fromJson(const {
        'id': 't',
        'entryMode': 'lottery',
      }, order: 0);
      expect(model.entity.entryMethod, TrackEntryMethod.directStart);
    });

    test('a track without an id is rejected', () {
      expect(
        () => TrackModel.fromJson(const {'nameAr': 'x'}, order: 0),
        throwsFormatException,
      );
    });
  });

  test('mock mode serves the bundled examples', () async {
    final source = TrackFakeDataSource(_DiskBundle(), latency: Duration.zero);
    expect(await source.getOnboardingTracks(), hasLength(3));
    expect(await source.getCatalog(), hasLength(3));
  });

  group('TrackRepositoryImpl', () {
    TrackModel model(String id, int order, [List<Object?> levels = const []]) =>
        TrackModel.fromJson({'id': id, 'levels': levels}, order: order);

    test('returns tracks in display order', () async {
      final result = await TrackRepositoryImpl(
        _FixedDataSource(onboarding: [model('b', 2), model('a', 1)]),
      ).getOnboardingTracks();

      expect(
        switch (result) {
          Ok(:final value) => value.map((t) => t.id),
          Err() => null,
        },
        ['a', 'b'],
      );
    });

    test('levels come with their track, fetched once', () async {
      final source = _FixedDataSource(
        onboarding: [
          model('t', 0, [
            {'id': 'l1'},
            {'id': 'l2'},
          ]),
        ],
      );
      final repository = TrackRepositoryImpl(source);
      await repository.getOnboardingTracks();

      final result = await repository.getLevels('t');
      expect((result as Ok<List<TrackLevel>>).value.map((l) => l.id), [
        'l1',
        'l2',
      ]);
      expect(source.onboardingCalls, 1);
    });

    test(
      'a track no audience leads to has its levels in the catalog',
      () async {
        final source = _FixedDataSource(
          catalog: [
            model('old', 0, [
              {'id': 'l1'},
            ]),
          ],
        );
        final result = await TrackRepositoryImpl(source).getLevels('old');
        expect((result as Ok<List<TrackLevel>>).value.single.id, 'l1');
        expect((source.onboardingCalls, source.catalogCalls), (1, 1));
      },
    );

    test('a track the server does not list has no levels', () async {
      final result = await TrackRepositoryImpl(
        _FixedDataSource(),
      ).getLevels('gone');
      expect((result as Ok<List<TrackLevel>>).value, isEmpty);
    });

    test('maps errors through the error funnel', () async {
      final result = await TrackRepositoryImpl(
        _FailingDataSource(),
      ).getPublishedTracks();

      expect(result, isA<Err<List<LearningTrack>>>());
      expect((result as Err).failure, isA<NetworkFailure>());
    });
  });

  group('units', () {
    final unitsBody =
        jsonDecode(
              File(
                TrackFakeDataSource.unitsAsset('lvl_gen_prea1'),
              ).readAsStringSync(),
            )
            as Map<String, Object?>;

    test('the example units parse with title and topic', () {
      final units = parseUnits(ApiClient.unwrap(unitsBody));
      final first = units.first.entity;
      expect(first.title, 'Hello!');
      expect(first.topic?.of('ar'), 'التحيات والتعارف');
    });

    test('a unit without a topic has none', () {
      final unit = TrackUnitModel.fromJson(const {'id': 'u1'}).entity;
      expect(unit.topic, isNull);
      expect(unit.title, '');
    });

    test('GET /api/v1/app/levels/{id}/units', () async {
      final adapter = FakeHttpAdapter(
        (_) => FakeResponse(200, body: unitsBody),
      );
      final client = ApiClient(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
      );

      final units = await TrackRemoteDataSourceImpl(
        client,
      ).getUnits('lvl_gen_prea1');

      expect(
        adapter.requests.single.path,
        '/api/v1/app/levels/lvl_gen_prea1/units',
      );
      expect(units, hasLength(2));
    });

    test('mock mode serves a default example to other levels', () async {
      final source = TrackFakeDataSource(_DiskBundle(), latency: Duration.zero);
      final grade = await source.getUnits('lvl_emar_07');
      expect(grade.first.entity.title, 'Unit 1: Back to School');
      final other = await source.getUnits('lvl_gen_b2');
      expect(other.first.entity.id, 'unit_01');
    });

    test('the repository returns units in display order', () async {
      final result = await TrackRepositoryImpl(
        _FixedDataSource(
          units: [
            TrackUnitModel.fromJson(const {'id': 'b', 'order': 2}),
            TrackUnitModel.fromJson(const {'id': 'a', 'order': 1}),
          ],
        ),
      ).getUnits('l');
      expect(
        switch (result) {
          Ok(:final value) => value.map((u) => u.id),
          Err() => null,
        },
        ['a', 'b'],
      );
    });
  });
}
