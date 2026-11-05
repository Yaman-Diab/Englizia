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
import 'package:englizia/features/tracks/data/models/track_level_model.dart';
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

List<LearningTrack> mockPublishedTracks() => [
  for (final item
      in _asset('assets/mock/tracks/published_tracks.json')! as List)
    TrackModel.fromJson(asJsonMap(item)).entity,
];

List<TrackLevel> mockEmarLevels() => [
  for (final item in _asset('assets/mock/tracks/levels_trk_emar.json')! as List)
    TrackLevelModel.fromJson(asJsonMap(item)).entity,
];

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

  @override
  Future<Result<Profile>> getProfile() async {
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
  Future<Result<void>> switchTrack(String enrollmentId) async {
    if (writeFailure case final failure?) return Err(failure);
    switches.add(enrollmentId);
    profile = profile.copyWith(
      tracks: [
        for (final track in profile.tracks)
          track.withActive(active: track.enrollmentId == enrollmentId),
      ],
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> changeLevel(String enrollmentId, String levelId) async {
    if (writeFailure case final failure?) return Err(failure);
    levels.add((enrollmentId, levelId));
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
