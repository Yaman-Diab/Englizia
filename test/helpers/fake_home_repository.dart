import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/data/datasources/home_remote_data_source.dart';
import 'package:englizia/features/home/data/models/home_model.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/repositories/home_repository.dart';
import 'package:englizia/features/me/data/datasources/profile_remote_data_source.dart';

/// The bundled home as [scenario]'s frame: the general track's, Emar's with
/// [emar], a child's with [kids]; its week ending around [now].
Map<String, Object?> mockHomeJson({
  HomeMockScenario scenario = HomeMockScenario.general,
  bool kids = false,
  bool emar = false,
  DateTime? now,
}) {
  final at = now ?? DateTime(2026, 11, 5, 10);
  final asset = kids
      ? HomeFakeDataSource.kidsAsset
      : emar
      ? HomeFakeDataSource.emarAsset
      : HomeFakeDataSource.generalAsset;
  final body = jsonDecode(File(asset).readAsStringSync());
  return applyScenario(
    ProfileFakeDataSource.moveToToday(asJsonMap(ApiClient.unwrap(body)), at),
    scenario,
    at,
  );
}

HomeSnapshot mockHome({
  HomeMockScenario scenario = HomeMockScenario.general,
  bool kids = false,
  bool emar = false,
  DateTime? now,
}) => HomeModel(
  mockHomeJson(scenario: scenario, kids: kids, emar: emar, now: now),
).toEntity();

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository(this.home, {this.failure, this.kept});

  /// What the server answers, unless [failure].
  HomeSnapshot? home;
  Failure? failure;
  HomeSnapshot? kept;

  /// When set, an answer waits for it.
  Future<void>? gate;
  int fetches = 0;
  final seen = <String>{};
  String? openingDay;

  @override
  HomeSnapshot? get keptHome => kept;

  @override
  Future<Result<HomeSnapshot>> getHome() async {
    fetches++;
    if (gate case final gate?) await gate;
    if (failure case final failure?) return Err(failure);
    final home = this.home;
    if (home == null) return const Err(UnknownFailure());
    return Ok(home);
  }

  @override
  bool openingShownOn(String dayKey) => openingDay == dayKey;

  @override
  Future<void> setOpeningShown(String dayKey) async => openingDay = dayKey;

  @override
  Set<String> get seenEvents => {...seen};

  @override
  Future<void> markEventSeen(String id) async => seen.add(id);
}
