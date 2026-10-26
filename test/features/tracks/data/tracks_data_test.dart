import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/tracks/data/datasources/track_remote_data_source.dart';
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
}

class _FixedDataSource implements TrackRemoteDataSource {
  _FixedDataSource(this.models);

  final List<TrackModel> models;

  @override
  Future<List<TrackModel>> getPublishedTracks() async => models;
}

void main() {
  test('the example response parses into tracks', () {
    final tracks = parseTracks(ApiClient.unwrap(exampleBody));

    expect(tracks.map((t) => t.entity.id), ['trk_general', 'trk_kids']);
    final general = tracks.first.entity;
    expect(
      general.title,
      const LocalizedText(ar: 'الإنجليزية العامة', en: 'General English'),
    );
    expect(general.audience, TrackAudience.self);
    expect(general.entryMethod, TrackEntryMethod.placementTest);
    expect(tracks.last.entity.audience, TrackAudience.child);
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

  test('the remote data source calls GET /api/v1/tracks', () async {
    final adapter = FakeHttpAdapter(
      (_) => FakeResponse(200, body: exampleBody),
    );
    final client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

    final tracks = await TrackRemoteDataSourceImpl(client).getPublishedTracks();

    expect(adapter.requests.single.path, '/api/v1/tracks');
    expect(tracks, hasLength(2));
  });

  test('mock mode serves the bundled example', () async {
    final tracks = await TrackFakeDataSource(
      _DiskBundle(),
      latency: Duration.zero,
    ).getPublishedTracks();
    expect(tracks.map((t) => t.entity.id), ['trk_general', 'trk_kids']);
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
}
