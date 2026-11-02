import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/features/talk/data/models/talk_model.dart';
import 'package:flutter/services.dart';

abstract interface class TalkRemoteDataSource {
  Future<TalkHomeModel> getHome();

  Future<ScenarioModel> getScenario(String id);

  Future<void> start(Map<String, Object?> request);

  Future<TalkReplyModel> say(
    String conversationId,
    Map<String, Object?> request,
  );

  Future<void> end(String conversationId, Map<String, Object?> request);

  Future<TalkNotesModel> notes(String conversationId);
}

final class TalkRemoteDataSourceImpl implements TalkRemoteDataSource {
  const TalkRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<TalkHomeModel> getHome() async =>
      TalkHomeModel(asJsonMap(await _client.get(ApiEndpoints.talk)));

  @override
  Future<ScenarioModel> getScenario(String id) async => ScenarioModel(
    asJsonMap(await _client.get(ApiEndpoints.talkScenario(id))),
  );

  @override
  Future<void> start(Map<String, Object?> request) =>
      _client.post(ApiEndpoints.talkConversations, data: request);

  @override
  Future<TalkReplyModel> say(
    String conversationId,
    Map<String, Object?> request,
  ) async => TalkReplyModel(
    asJsonMap(
      await _client.post(ApiEndpoints.talkTurns(conversationId), data: request),
    ),
  );

  @override
  Future<void> end(String conversationId, Map<String, Object?> request) =>
      _client.post(ApiEndpoints.talkEnd(conversationId), data: request);

  @override
  Future<TalkNotesModel> notes(String conversationId) async => TalkNotesModel(
    asJsonMap(await _client.get(ApiEndpoints.talkNotes(conversationId))),
  );
}

/// Mock mode (`env/mock.json`): the contract's example from the bundled assets
/// the tests also use, with each scenario's replies in order. The second turn
/// fails once, so «تعذّر الرد» can be seen, and the notes are still being made
/// the first time they are asked for. Deleted once the endpoints are
/// confirmed.
final class TalkFakeDataSource implements TalkRemoteDataSource {
  TalkFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
    this.replyLatency = const Duration(milliseconds: 1400),
  });

  static const homeAsset = 'assets/mock/talk/home.json';
  static const scenariosAsset = 'assets/mock/talk/scenarios.json';
  static const _failingTurn = 1;

  final AssetBundle _bundle;
  final Duration latency;

  /// The design's wait while the character thinks.
  final Duration replyLatency;

  final _turns = <String, int>{};
  final _said = <String, List<String>>{};
  final _notesAsked = <String>{};
  final _scenarioOf = <String, String>{};
  var _failed = false;

  Future<Map<String, Object?>> _scenarios() async =>
      asJsonMap(jsonDecode(await _bundle.loadString(scenariosAsset)));

  Future<Map<String, Object?>> _scenario(String id) async {
    final scenarios = await _scenarios();
    return asJsonMap(scenarios[id] ?? scenarios.values.first);
  }

  @override
  Future<TalkHomeModel> getHome() async {
    await Future<void>.delayed(latency);
    return TalkHomeModel(
      asJsonMap(
        ApiClient.unwrap(jsonDecode(await _bundle.loadString(homeAsset))),
      ),
    );
  }

  @override
  Future<ScenarioModel> getScenario(String id) async {
    await Future<void>.delayed(latency);
    return ScenarioModel(await _scenario(id));
  }

  @override
  Future<void> start(Map<String, Object?> request) async {
    await Future<void>.delayed(latency);
    final id = request.readString('conversationId')!;
    _scenarioOf[id] = request.readString('scenarioId')!;
    _turns[id] = 0;
    _said[id] = [];
  }

  @override
  Future<TalkReplyModel> say(
    String conversationId,
    Map<String, Object?> request,
  ) async {
    await Future<void>.delayed(replyLatency);
    final turn = _turns[conversationId] ?? 0;
    if (turn == _failingTurn && !_failed) {
      _failed = true;
      throw const NetworkException('connectionError');
    }
    final replies = (await _scenario(
      _scenarioOf[conversationId] ?? '',
    )).readList('replies')!;
    _turns[conversationId] = turn + 1;
    _said[conversationId]?.add(request.readString('text') ?? '');
    return TalkReplyModel(
      asJsonMap(replies[turn.clamp(0, replies.length - 1)]),
    );
  }

  @override
  Future<void> end(String conversationId, Map<String, Object?> request) =>
      Future<void>.delayed(latency);

  /// The scenario's sample notes, on the lines the learner said.
  @override
  Future<TalkNotesModel> notes(String conversationId) async {
    await Future<void>.delayed(latency);
    if (_notesAsked.add(conversationId)) {
      return const TalkNotesModel({'status': 'pending'});
    }
    final said = _said[conversationId] ?? const [];
    final samples = (await _scenario(
      _scenarioOf[conversationId] ?? '',
    )).readList('notes');
    return TalkNotesModel({
      'status': 'ready',
      'notes': [
        for (final sample in samples ?? const <Object?>[])
          if (asJsonMap(sample).readInt('turn')! < said.length)
            {
              ...asJsonMap(sample),
              'said': said[asJsonMap(sample).readInt('turn')!],
            },
      ],
    });
  }
}
