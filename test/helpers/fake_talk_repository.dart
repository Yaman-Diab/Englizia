import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/talk/data/datasources/talk_remote_data_source.dart';
import 'package:englizia/features/talk/data/models/talk_model.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/domain/repositories/talk_repository.dart';

Map<String, Object?> _scenarioJson([String id = 'sc_fragile_box']) => asJsonMap(
  asJsonMap(
    jsonDecode(File(TalkFakeDataSource.scenariosAsset).readAsStringSync()),
  )[id],
);

/// The mock «تحدّث».
TalkHome mockTalkHome() => TalkHomeModel(
  asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(TalkFakeDataSource.homeAsset).readAsStringSync()),
    ),
  ),
).toEntity();

/// The design's scenario: Jake and the fragile box.
Scenario mockScenario() => ScenarioModel(_scenarioJson()).toEntity();

/// Jake's replies, turn by turn.
List<TalkReply> mockReplies() => [
  for (final reply in _scenarioJson().readList('replies')!)
    TalkReplyModel(asJsonMap(reply)).toEntity(),
];

class FakeTalkRepository implements TalkRepository {
  FakeTalkRepository({TalkHome? home, Scenario? scenario})
    : home = home ?? mockTalkHome(),
      scenario = scenario ?? mockScenario();

  TalkHome? home;
  Scenario scenario;

  /// What the server answers instead, for each call that can fail.
  Failure? homeFailure;
  Failure? scenarioFailure;
  Failure? startFailure;

  /// How many turns fail before one gets through.
  var failingTurns = 0;
  final said = <(int, String, SaidVia)>[];
  final ended = <String>[];
  var starts = 0;

  @override
  TalkHome? get keptHome => home;

  @override
  Future<Result<TalkHome>> getHome() async {
    if (homeFailure case final failure?) return Err(failure);
    return Ok(home!);
  }

  @override
  Future<Result<Scenario>> getScenario(String id) async {
    if (scenarioFailure case final failure?) return Err(failure);
    return Ok(scenario);
  }

  @override
  Future<Result<String>> start(String scenarioId) async {
    if (startFailure case final failure?) return Err(failure);
    starts++;
    return const Ok('conv_1');
  }

  @override
  Future<Result<TalkReply>> say(
    String conversationId, {
    required int turn,
    required String text,
    required SaidVia via,
  }) async {
    said.add((turn, text, via));
    if (failingTurns > 0) {
      failingTurns--;
      return const Err(NetworkFailure());
    }
    final replies = mockReplies();
    return Ok(replies[turn.clamp(0, replies.length - 1)]);
  }

  @override
  Future<void> end(String conversationId) async => ended.add(conversationId);
}
