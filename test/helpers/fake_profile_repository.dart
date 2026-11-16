import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/me/data/datasources/profile_remote_data_source.dart';
import 'package:englizia/features/me/data/models/profile_model.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';
import 'package:englizia/features/tracks/data/datasources/track_remote_data_source.dart';
import 'package:englizia/features/tracks/data/models/track_model.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';

Object? _asset(String path) =>
    ApiClient.unwrap(jsonDecode(File(path).readAsStringSync()));

/// The bundled profile, its week ending around [now].
Map<String, Object?> mockProfileJson({bool kids = false, DateTime? now}) =>
    ProfileFakeDataSource.moveToToday(
      asJsonMap(
        _asset(
          kids ? ProfileFakeDataSource.kidsAsset : ProfileFakeDataSource.asset,
        ),
      ),
      now ?? DateTime(2026, 11, 5, 10),
    );

Profile mockProfile({bool kids = false, DateTime? now}) =>
    ProfileModel(mockProfileJson(kids: kids, now: now)).toEntity();

List<TrackModel> _catalog() =>
    parseCatalog(_asset(TrackFakeDataSource.catalogAsset));

List<LearningTrack> mockPublishedTracks() => [
  for (final model in _catalog()) model.entity,
];

List<TrackLevel> mockEmarLevels() =>
    _catalog().firstWhere((model) => model.entity.id == 'trk_emar').levels;

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this.profile, {this.firstView = false});

  Profile profile;
  Profile? kept;
  Failure? failure;

  /// What a write answers.
  Failure? writeFailure;
  bool firstView;
  final names = <String>[];
  final switches = <String>[];
  final levels = <(String, String)>[];

  @override
  Profile? get keptProfile => kept;

  var fetches = 0;

  @override
  Future<Result<Profile>> getProfile() async {
    fetches++;
    if (failure case final failure?) return Err(failure);
    return Ok(profile);
  }

  @override
  Future<Result<void>> rename(String name) async {
    if (writeFailure case final failure?) return Err(failure);
    names.add(name);
    profile = profile.copyWith(name: name);
    return const Ok(null);
  }

  @override
  Future<Result<void>> switchTrack(String trackId) async {
    if (writeFailure case final failure?) return Err(failure);
    switches.add(trackId);
    profile = profile.copyWith(
      tracks: [
        for (final track in profile.tracks)
          track.withActive(active: track.trackId == trackId),
      ],
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> changeLevel(String trackId, String levelId) async {
    if (writeFailure case final failure?) return Err(failure);
    levels.add((trackId, levelId));
    return const Ok(null);
  }

  Preferences preferences = const Preferences(
    dailyGoalMinutes: 10,
    notifications: true,
    reminderHour: 20,
  );
  final saved = <Preferences>[];
  final passwords = <(String, String)>[];
  final deletions = <String?>[];

  /// What a password check answers: a wrong one, or none.
  Failure? passwordFailure;

  @override
  Future<Result<Preferences>> getPreferences() async {
    if (failure case final failure?) return Err(failure);
    return Ok(preferences);
  }

  @override
  Future<Result<void>> savePreferences(Preferences preferences) async {
    if (writeFailure case final failure?) return Err(failure);
    saved.add(preferences);
    this.preferences = preferences;
    return const Ok(null);
  }

  @override
  Future<Result<void>> changePassword({
    required String current,
    required String next,
  }) async {
    if (passwordFailure case final failure?) return Err(failure);
    passwords.add((current, next));
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteAccount({String? password}) async {
    if (passwordFailure case final failure?) return Err(failure);
    deletions.add(password);
    return const Ok(null);
  }

  @override
  bool firstViewOn(DateTime day) => firstView;
}
