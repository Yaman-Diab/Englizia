import 'dart:convert';

import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/server_unit.dart';
import 'package:englizia/features/tracks/data/datasources/enrollments_reader.dart';
import 'package:englizia/features/tracks/data/models/track_model.dart';
import 'package:englizia/features/tracks/data/models/track_unit_model.dart';
import 'package:englizia/features/tracks/domain/entities/track_unit.dart';
import 'package:flutter/services.dart';

abstract interface class TrackRemoteDataSource {
  /// The tracks each onboarding audience leads to, from `system/config`,
  /// which needs no session: onboarding runs before the account exists.
  Future<List<TrackModel>> getOnboardingTracks();

  /// Every published track, for a learner with a session.
  Future<List<TrackModel>> getCatalog();

  /// The units of the level the learner is in, which must be [levelId] when
  /// it is given.
  Future<List<TrackUnitModel>> getUnits(String? levelId);
}

final class TrackRemoteDataSourceImpl implements TrackRemoteDataSource {
  const TrackRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<TrackModel>> getOnboardingTracks() async => parseOnboarding(
    await _client.get(
      ApiEndpoints.systemConfig,
      options: ApiClient.publicOptions,
    ),
  );

  @override
  Future<List<TrackModel>> getCatalog() async =>
      parseCatalog(await _client.get(ApiEndpoints.tracks));

  /// The server has no call for a level's units: they are the active
  /// track's map's (the backend's answers of 2026-11-23, tracks.md 3).
  @override
  Future<List<TrackUnitModel>> getUnits(String? levelId) async {
    final trackId = await EnrollmentsReader(_client).activeTrackId();
    if (trackId == null) return const [];
    final map = asJsonMap(await _client.get(ApiEndpoints.levelMap(trackId)));
    if (levelId != null && map.readMap('level')?.readString('id') != levelId) {
      return const [];
    }
    return [
      for (final (i, unit) in mapUnits(map).indexed)
        if (unit.readString('id') case final id?)
          TrackUnitModel(
            TrackUnit(
              id: id,
              order: i + 1,
              title: unit.readString('titleAr') ?? '',
              topic: switch (unit.readString('titleEn')) {
                final en? => LocalizedText(
                  ar: unit.readString('titleAr') ?? '',
                  en: en,
                ),
                null => null,
              },
            ),
          ),
    ];
  }
}

/// Mock mode (`env/mock.json`): example responses in the server's shape,
/// read from the bundled assets the tests also use. Units are deleted once
/// their endpoint exists (docs/STATUS.md).
final class TrackFakeDataSource implements TrackRemoteDataSource {
  const TrackFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
  });

  /// `system/config`, shared with the settings' mock.
  static const configAsset = 'assets/mock/settings/system_config.json';
  static const catalogAsset = 'assets/mock/tracks/catalog.json';

  /// Units of the levels that have their own example; any other level
  /// gets [defaultUnitsAsset].
  static const levelsWithUnits = {'lvl_gen_prea1', 'lvl_emar_07'};
  static String unitsAsset(String levelId) => levelsWithUnits.contains(levelId)
      ? 'assets/mock/tracks/units_$levelId.json'
      : defaultUnitsAsset;
  static const defaultUnitsAsset = 'assets/mock/tracks/units_default.json';

  final AssetBundle _bundle;

  /// Lets loading states show in demos as they would on a real network.
  final Duration latency;

  Future<Object?> _read(String asset) async {
    await Future<void>.delayed(latency);
    return ApiClient.unwrap(jsonDecode(await _bundle.loadString(asset)));
  }

  @override
  Future<List<TrackModel>> getOnboardingTracks() async =>
      parseOnboarding(await _read(configAsset));

  @override
  Future<List<TrackModel>> getCatalog() async =>
      parseCatalog(await _read(catalogAsset));

  @override
  Future<List<TrackUnitModel>> getUnits(String? levelId) async =>
      parseUnits(await _read(unitsAsset(levelId ?? '')));
}

/// `SystemConfigDto.onboarding`: the tracks by audience, in that order.
/// An audience the app doesn't know leaves its tracks unsuggested.
List<TrackModel> parseOnboarding(Object? data) {
  final groups = asJsonMap(data).readList('onboarding');
  if (groups == null) {
    throw FormatException('Expected the onboarding tracks, got $data');
  }
  final tracks = <TrackModel>[];
  for (final item in groups) {
    final group = asJsonMap(item);
    final audience = TrackModel.audienceOf(group.readString('audience'));
    for (final track in group.readList('tracks') ?? const []) {
      tracks.add(
        TrackModel.fromJson(
          asJsonMap(track),
          order: tracks.length,
          audience: audience,
        ),
      );
    }
  }
  return tracks;
}

/// `ListDataOfTrackCatalogItemDto`: the tracks under `items`.
List<TrackModel> parseCatalog(Object? data) =>
    switch (asJsonMap(data).readList('items')) {
      final items? => [
        for (final (index, item) in items.indexed)
          TrackModel.fromJson(asJsonMap(item), order: index),
      ],
      null => throw FormatException('Expected a list of tracks, got $data'),
    };

List<TrackUnitModel> parseUnits(Object? data) => switch (data) {
  final List<Object?> items => [
    for (final item in items) TrackUnitModel.fromJson(asJsonMap(item)),
  ],
  _ => throw FormatException('Expected a list of units, got $data'),
};
