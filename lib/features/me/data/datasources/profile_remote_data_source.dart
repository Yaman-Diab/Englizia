import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/me/data/models/profile_model.dart';
import 'package:flutter/services.dart';

/// Days in a study week: Saturday to Friday.
const _weekLength = 7;

abstract interface class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();

  Future<void> rename(String name);

  Future<void> switchTrack(String enrollmentId);

  Future<void> changeLevel(String enrollmentId, String levelId);

  Future<Map<String, Object?>> getPreferences();

  Future<void> savePreferences(Map<String, Object?> request);

  Future<void> changePassword(String current, String next);

  Future<void> deleteAccount(String? password);
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

  @override
  Future<Map<String, Object?>> getPreferences() async =>
      asJsonMap(await _client.get(ApiEndpoints.preferences));

  @override
  Future<void> savePreferences(Map<String, Object?> request) =>
      _client.put(ApiEndpoints.preferences, data: request);

  @override
  Future<void> changePassword(String current, String next) => _client.post(
    ApiEndpoints.changePassword,
    data: {'currentPassword': current, 'newPassword': next},
  );

  // ASSUMPTION(api): `DELETE /api/v1/app/me`, docs/api/me.md.
  @override
  Future<void> deleteAccount(String? password) =>
      _client.delete(ApiEndpoints.me, data: {'password': ?password});
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

  /// The week runs from Saturday to Friday and holds [now]: its days are
  /// this week's, and each keeps the minutes the bundled JSON has at the same
  /// distance from its «today». Days the JSON doesn't have come with no
  /// minutes. The next test is still days off.
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
    final oldToday = week?.readInt('today') ?? 0;
    // Saturday is 0 and Friday 6: the week's first day is Saturday.
    final todayIndex = (today.weekday + 1) % _weekLength;
    return {
      ...json,
      if (week != null)
        'week': {
          ...week,
          'today': todayIndex,
          'days': [
            for (var index = 0; index < _weekLength; index++)
              {
                ...?_bundledDay(days, index - todayIndex + oldToday),
                'date': day(index - todayIndex),
              },
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

  /// The bundled day at [index] of its week, or null past its ends.
  static Map<String, Object?>? _bundledDay(List<Object?> days, int index) =>
      index >= 0 && index < days.length ? asJsonMap(days[index]) : null;

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

  Map<String, Object?> _preferences = const {
    'dailyGoalMinutes': 10,
    'notifications': true,
    'reminderTime': '20:00',
  };

  @override
  Future<Map<String, Object?>> getPreferences() async {
    await Future<void>.delayed(latency);
    return _preferences;
  }

  @override
  Future<void> savePreferences(Map<String, Object?> request) async {
    await Future<void>.delayed(latency);
    _preferences = request;
  }

  /// The mock's password is `password`, so a wrong one can be seen.
  @override
  Future<void> changePassword(String current, String next) async {
    await Future<void>.delayed(latency);
    if (current != mockPassword) throw _wrong('currentPassword');
  }

  @override
  Future<void> deleteAccount(String? password) async {
    await Future<void>.delayed(latency);
    if (password != null && password != mockPassword) {
      throw _wrong('password');
    }
  }

  static const mockPassword = 'password';

  /// ASSUMPTION(api): a wrong password is a validation error on its field.
  static ApiException _wrong(String field) => ApiException(
    statusCode: 400,
    code: ApiErrorCodes.validationFailed,
    fieldCodes: {
      field: const ['wrong'],
    },
  );
}
