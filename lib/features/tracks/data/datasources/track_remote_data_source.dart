import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/tracks/data/models/track_level_model.dart';
import 'package:englizia/features/tracks/data/models/track_model.dart';
import 'package:flutter/services.dart';

abstract interface class TrackRemoteDataSource {
  Future<List<TrackModel>> getPublishedTracks();

  Future<List<TrackLevelModel>> getLevels(String trackId);
}

final class TrackRemoteDataSourceImpl implements TrackRemoteDataSource {
  const TrackRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<TrackModel>> getPublishedTracks() async =>
      parseTracks(await _client.get(ApiEndpoints.tracks));

  @override
  Future<List<TrackLevelModel>> getLevels(String trackId) async =>
      parseLevels(await _client.get(ApiEndpoints.trackLevels(trackId)));
}

/// Mock mode (`env/mock.json`): the contract's example response, read from
/// the bundled asset the tests also use. Deleted once the endpoint is
/// confirmed (docs/STATUS.md).
final class TrackFakeDataSource implements TrackRemoteDataSource {
  const TrackFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
  });

  static const asset = 'assets/mock/tracks/published_tracks.json';

  /// Levels per track: `levels_<trackId>.json` next to [asset].
  static String levelsAsset(String trackId) =>
      'assets/mock/tracks/levels_$trackId.json';

  final AssetBundle _bundle;

  /// Lets loading states show in demos as they would on a real network.
  final Duration latency;

  @override
  Future<List<TrackModel>> getPublishedTracks() async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return parseTracks(ApiClient.unwrap(body));
  }

  @override
  Future<List<TrackLevelModel>> getLevels(String trackId) async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(levelsAsset(trackId)));
    return parseLevels(ApiClient.unwrap(body));
  }
}

List<TrackModel> parseTracks(Object? data) => switch (data) {
  final List<Object?> items => [
    for (final item in items) TrackModel.fromJson(asJsonMap(item)),
  ],
  _ => throw FormatException('Expected a list of tracks, got $data'),
};

List<TrackLevelModel> parseLevels(Object? data) => switch (data) {
  final List<Object?> items => [
    for (final item in items) TrackLevelModel.fromJson(asJsonMap(item)),
  ],
  _ => throw FormatException('Expected a list of levels, got $data'),
};
