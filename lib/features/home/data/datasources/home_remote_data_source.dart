import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/data/models/home_model.dart';
import 'package:englizia/features/me/data/datasources/profile_remote_data_source.dart';
import 'package:flutter/services.dart';

abstract interface class HomeRemoteDataSource {
  Future<HomeModel> getHome();
}

final class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  const HomeRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<HomeModel> getHome() async =>
      HomeModel(asJsonMap(await _client.get(ApiEndpoints.home)));
}

/// Mock mode (`env/mock.json`): the bundled home of the active enrollment,
/// its week moved to this one, played as the design's [scenario]. It acts as
/// the server would: a lesson completed on the phone becomes done, its
/// minutes count today, the streak grows when the goal is reached, and a unit
/// finished opens the next. Deleted once the endpoint is confirmed.
final class HomeFakeDataSource implements HomeRemoteDataSource {
  HomeFakeDataSource(
    this._bundle, {
    required Future<String?> Function() activeEnrollmentId,
    required bool Function(String lessonId) completedOnPhone,
    this.kids = false,
    this.latency = const Duration(milliseconds: 600),
    DateTime Function()? now,
  }) : _activeEnrollmentId = activeEnrollmentId,
       _completedOnPhone = completedOnPhone,
       _now = now ?? DateTime.now;

  static const generalAsset = 'assets/mock/home/home_general.json';
  static const emarAsset = 'assets/mock/home/home_emar.json';
  static const kidsAsset = 'assets/mock/home/home_kids.json';

  /// How long the [HomeMockScenario.slow] load takes.
  static const slowLatency = Duration(seconds: 6);

  final AssetBundle _bundle;
  final Future<String?> Function() _activeEnrollmentId;
  final bool Function(String lessonId) _completedOnPhone;
  final bool kids;
  final Duration latency;
  final DateTime Function() _now;

  /// Each asset's home as the mock server holds it now.
  final _homes = <String, Map<String, Object?>>{};

  /// The lessons already counted, so one done twice counts once.
  final _counted = <String, Set<String>>{};
  var _calls = 0;
  var _scenario = HomeMockScenario.general;

  HomeMockScenario get scenario => _scenario;

  /// Starts [value] afresh, for every track.
  set scenario(HomeMockScenario value) {
    _scenario = value;
    _homes.clear();
    _counted.clear();
    _calls = 0;
  }

  /// The scenario's clock: the evening for [HomeMockScenario.atRisk].
  DateTime now() {
    final now = _now();
    return _scenario == HomeMockScenario.atRisk
        ? DateTime(now.year, now.month, now.day, 19, 30)
        : now;
  }

  @override
  Future<HomeModel> getHome() async {
    await Future<void>.delayed(
      _scenario == HomeMockScenario.slow ? slowLatency : latency,
    );
    _calls++;
    switch (_scenario) {
      case HomeMockScenario.offline || HomeMockScenario.offlineEmpty:
        throw const NetworkException('connectionError');
      case HomeMockScenario.refreshFails when _calls > 1:
        throw const ApiException(statusCode: 500);
      default:
        break;
    }
    final asset = await _assetOf();
    final home = _homes[asset] ??= applyScenario(
      await _load(asset),
      _scenario,
      now(),
    );
    _serve(home, _counted.putIfAbsent(asset, () => {}));
    return HomeModel(copyJson(home));
  }

  Future<String> _assetOf() async {
    if (kids) return kidsAsset;
    return switch (await _activeEnrollmentId()) {
      'enr_emar' => emarAsset,
      'enr_kids' => kidsAsset,
      _ => generalAsset,
    };
  }

  Future<Map<String, Object?>> _load(String asset) async {
    final body = jsonDecode(await _bundle.loadString(asset));
    return ProfileFakeDataSource.moveToToday(
      asJsonMap(ApiClient.unwrap(body)),
      now(),
    );
  }

  /// What the server would have done with the lessons completed since.
  void _serve(Map<String, Object?> home, Set<String> counted) {
    final units = [
      for (final item in home.readList('units') ?? const <Object?>[])
        asJsonMap(item),
    ];
    final current = units.indexWhere((unit) => unit['status'] == 'current');
    if (current < 0) return;
    final lessons = [
      for (final item
          in units[current].readList('lessons') ?? const <Object?>[])
        asJsonMap(item),
    ];
    for (final lesson in lessons) {
      final id = lesson.readString('id');
      if (id == null || lesson['done'] == true) continue;
      if (counted.contains(id) || !_completedOnPhone(id)) continue;
      counted.add(id);
      lesson['done'] = true;
      lesson.remove('resume');
      _count(home, lesson.readInt('minutes') ?? 0);
      final cards = home.readMap('cards');
      if (cards?.readMap('levelCheck')?.readString('lessonId') == id) {
        cards!.remove('levelCheck');
      }
    }
    if (lessons.isEmpty || lessons.any((lesson) => lesson['done'] != true)) {
      return;
    }
    if (current + 1 < units.length) {
      moveCurrentUnit(home, current + 1);
    } else {
      moveCurrentUnit(home, units.length);
      (home['level']! as Map<String, Object?>)['completed'] = true;
    }
  }

  /// One more lesson done today: its minutes, and the streak if the goal is
  /// reached by them.
  void _count(Map<String, Object?> home, int minutes) {
    if (home.readMap('learner') case final learner?) {
      learner['lessonsDone'] = (learner.readInt('lessonsDone') ?? 0) + 1;
    }
    final week = home.readMap('week');
    final days = week?.readList('days');
    final today = week?.readInt('today');
    final goal = week?.readInt('goalMinutes') ?? 0;
    if (days == null || today == null || today >= days.length) return;
    final day = asJsonMap(days[today]);
    final before = day.readInt('minutes') ?? 0;
    day['minutes'] = before + minutes;
    final streak = home.readMap('streak');
    if (streak == null || before >= goal || before + minutes < goal) return;
    final current = (streak.readInt('current') ?? 0) + 1;
    streak['current'] = current;
    if ((streak.readInt('longest') ?? 0) < current) streak['longest'] = current;
  }
}
