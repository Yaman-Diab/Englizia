import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/me/data/models/profile_model.dart';
import 'package:flutter/services.dart';

abstract interface class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();

  Future<void> rename(String name);

  Future<void> switchTrack(String enrollmentId);

  Future<void> changeLevel(String enrollmentId, String levelId);
}

final class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<ProfileModel> getProfile() async =>
      ProfileModel(asJsonMap(await _client.get(ApiEndpoints.profile)));

  /// `PUT /api/v1/app/me` takes the whole account's settings, so the time
  /// zone and language are sent back as they are.
  @override
  Future<void> rename(String name) async {
    final me = asJsonMap(await _client.get(ApiEndpoints.me));
    await _client.put(
      ApiEndpoints.me,
      data: {
        'displayName': name,
        'timeZone': me.readString('timeZone'),
        'uiLanguage': me['uiLanguage'],
      },
    );
  }

  @override
  Future<void> switchTrack(String enrollmentId) => _client.put(
    ApiEndpoints.activeEnrollment,
    data: {'enrollmentId': enrollmentId},
  );

  // ASSUMPTION(api): `levelId` on the enrollment, docs/api/me.md.
  @override
  Future<void> changeLevel(String enrollmentId, String levelId) => _client
      .patch(ApiEndpoints.enrollment(enrollmentId), data: {'levelId': levelId});
}

/// Mock mode (`env/mock.json`): the bundled profile, its days moved to this
/// week, a child's with `env/mock_kids.json`. Changes stay in memory. Deleted
/// once the endpoints are confirmed.
final class ProfileFakeDataSource implements ProfileRemoteDataSource {
  ProfileFakeDataSource(
    this._bundle, {
    this.kids = false,
    DateTime Function()? now,
    this.latency = const Duration(milliseconds: 500),
  }) : _now = now ?? DateTime.now;

  static const asset = 'assets/mock/me/profile.json';
  static const kidsAsset = 'assets/mock/me/profile_kids.json';

  final AssetBundle _bundle;
  final bool kids;
  final DateTime Function() _now;
  final Duration latency;
  Map<String, Object?>? _profile;

  Future<Map<String, Object?>> _load() async {
    if (_profile case final profile?) return profile;
    final body = jsonDecode(await _bundle.loadString(kids ? kidsAsset : asset));
    return _profile = moveToToday(asJsonMap(ApiClient.unwrap(body)), _now());
  }

  /// The week's days end around [now], and the next test is still days off.
  static Map<String, Object?> moveToToday(
    Map<String, Object?> json,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    String day(int offset) =>
        today.add(Duration(days: offset)).toIso8601String().substring(0, 10);
    final week = json.readMap('week');
    final placement = json.readMap('placement');
    final days = week?.readList('days') ?? const <Object?>[];
    final todayIndex = week?.readInt('today') ?? 0;
    return {
      ...json,
      if (week != null)
        'week': {
          ...week,
          'days': [
            for (final (index, item) in days.indexed)
              {...asJsonMap(item), 'date': day(index - todayIndex)},
          ],
        },
      if (placement != null)
        'placement': {
          ...placement,
          'takenAt': day(-(placement.readInt('takenDaysAgo') ?? 18)),
          'retestAt': day(placement.readInt('retestInDays') ?? 12),
        },
    };
  }

  @override
  Future<ProfileModel> getProfile() async {
    await Future<void>.delayed(latency);
    return ProfileModel(await _load());
  }

  @override
  Future<void> rename(String name) async {
    await Future<void>.delayed(latency);
    _profile = {...await _load(), 'name': name};
  }

  @override
  Future<void> switchTrack(String enrollmentId) async {
    await Future<void>.delayed(latency);
    final profile = await _load();
    _profile = {
      ...profile,
      'tracks': [
        for (final item in profile.readList('tracks') ?? const <Object?>[])
          {
            ...asJsonMap(item),
            'active':
                asJsonMap(item).readString('enrollmentId') == enrollmentId,
          },
      ],
    };
  }

  /// The grade's names come from the mock's own `mockLevels`.
  @override
  Future<void> changeLevel(String enrollmentId, String levelId) async {
    await Future<void>.delayed(latency);
    final profile = await _load();
    final level = profile.readMap('mockLevels')?.readMap(levelId) ?? const {};
    _profile = {
      ...profile,
      'tracks': [
        for (final item in profile.readList('tracks') ?? const <Object?>[])
          if (asJsonMap(item).readString('enrollmentId') == enrollmentId)
            {...asJsonMap(item), ...level, 'levelId': levelId, 'unit': 1}
          else
            item,
      ],
    };
  }
}
