import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/tracks/data/datasources/track_remote_data_source.dart';
import 'package:englizia/features/tracks/data/models/track_level_model.dart';
import 'package:englizia/features/tracks/data/models/track_model.dart';
import 'package:englizia/features/tracks/data/repositories/track_repository_impl.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';

/// The contract's example response: the same file mock mode serves.
final exampleBody =
    jsonDecode(File(TrackFakeDataSource.asset).readAsStringSync())
        as Map<String, Object?>;

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _FailingDataSource implements TrackRemoteDataSource {
  @override
  Future<List<TrackModel>> getPublishedTracks() async =>
      throw const NetworkException('connectionError');

  @override
  Future<List<TrackLevelModel>> getLevels(String trackId) async =>
      throw const NetworkException('connectionError');
}

class _FixedDataSource implements TrackRemoteDataSource {
  _FixedDataSource(this.models, [this.levels = const []]);

  final List<TrackModel> models;
  final List<TrackLevelModel> levels;

  @override
  Future<List<TrackModel>> getPublishedTracks() async => models;

  @override
  Future<List<TrackLevelModel>> getLevels(String trackId) async => levels;
}

void main() {
  test('the example response parses into tracks', () {
    final tracks = parseTracks(ApiClient.unwrap(exampleBody));

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
    expect(tracks.last.entity.audience, TrackAudience.schoolStudent);
    expect(tracks.last.entity.entryMethod, TrackEntryMethod.gradeSelection);
  });

  group('TrackModel', () {
    test('an unknown audience means not suggested', () {
      final model = TrackModel.fromJson(const {
        'id': 't',
        'onboardingAudience': 'teachers',
      });
      expect(model.entity.audience, isNull);
    });

    test('a track without an id is rejected', () {
      expect(
        () => TrackModel.fromJson(const {'title': {}}),
        throwsFormatException,
      );
    });
  });

  test('the remote data source calls GET /api/v1/app/tracks', () async {
    final adapter = FakeHttpAdapter(
      (_) => FakeResponse(200, body: exampleBody),
    );
    final client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

    final tracks = await TrackRemoteDataSourceImpl(client).getPublishedTracks();

    expect(adapter.requests.single.path, '/api/v1/app/tracks');
    expect(tracks, hasLength(3));
  });

  test('mock mode serves the bundled example', () async {
    final tracks = await TrackFakeDataSource(
      _DiskBundle(),
      latency: Duration.zero,
    ).getPublishedTracks();
    expect(tracks.map((t) => t.entity.id), [
      'trk_general',
      'trk_kids',
      'trk_emar',
    ]);
  });

  group('TrackRepositoryImpl', () {
    TrackModel model(String id, int order) =>
        TrackModel.fromJson({'id': id, 'order': order});

    test('returns tracks in display order', () async {
      final result = await TrackRepositoryImpl(
        _FixedDataSource([model('b', 2), model('a', 1)]),
      ).getPublishedTracks();

      expect(
        switch (result) {
          Ok(:final value) => value.map((t) => t.id),
          Err() => null,
        },
        ['a', 'b'],
      );
    });

    test('maps errors through the error funnel', () async {
      final result = await TrackRepositoryImpl(
        _FailingDataSource(),
      ).getPublishedTracks();

      expect(result, isA<Err<List<LearningTrack>>>());
      expect((result as Err).failure, isA<NetworkFailure>());
    });
  });

  group('levels', () {
    final levelsBody =
        jsonDecode(
              File(
                TrackFakeDataSource.levelsAsset('trk_emar'),
              ).readAsStringSync(),
            )
            as Map<String, Object?>;

    test('the example levels parse with grade and display group', () {
      final levels = parseLevels(ApiClient.unwrap(levelsBody));

      expect(levels, hasLength(12));
      final seventh = levels[6].entity;
      expect(seventh.schoolGrade, 7);
      expect(seventh.name.of('ar'), 'السابع');
      expect(seventh.group?.of('ar'), 'الحلقة الثانية');
      expect(levels.last.entity.name.of('ar'), 'البكالوريا');
    });

    test('a level without a display group has none', () {
      final level = TrackLevelModel.fromJson(const {'id': 'l1'}).entity;
      expect(level.group, isNull);
      expect(level.schoolGrade, isNull);
    });

    test('GET /api/v1/app/tracks/{id}/levels', () async {
      final adapter = FakeHttpAdapter(
        (_) => FakeResponse(200, body: levelsBody),
      );
      final client = ApiClient(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
      );

      final levels = await TrackRemoteDataSourceImpl(
        client,
      ).getLevels('trk_emar');

      expect(
        adapter.requests.single.path,
        '/api/v1/app/tracks/trk_emar/levels',
      );
      expect(levels, hasLength(12));
    });

    test('mock mode serves each track its own levels file', () async {
      final levels = await TrackFakeDataSource(
        _DiskBundle(),
        latency: Duration.zero,
      ).getLevels('trk_emar');
      expect(levels.first.entity.id, 'lvl_emar_01');
    });

    test('the repository returns levels in display order', () async {
      final result = await TrackRepositoryImpl(
        _FixedDataSource(const [], [
          TrackLevelModel.fromJson(const {'id': 'b', 'order': 2}),
          TrackLevelModel.fromJson(const {'id': 'a', 'order': 1}),
        ]),
      ).getLevels('t');
      expect(
        switch (result) {
          Ok(:final value) => value.map((l) => l.id),
          Err() => null,
        },
        ['a', 'b'],
      );
    });
  });
}
