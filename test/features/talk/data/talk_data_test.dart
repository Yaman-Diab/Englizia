import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/talk/data/datasources/talk_remote_data_source.dart';
import 'package:englizia/features/talk/data/models/talk_model.dart';
import 'package:englizia/features/talk/data/repositories/talk_repository_impl.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_http_adapter.dart';

Map<String, Object?> _body(String name) => asJsonMap(
  jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync()),
);

Map<String, Object?> _data(String name) =>
    asJsonMap(ApiClient.unwrap(_body(name)));

/// The server: what it holds, what it was sent, and whether it can be reached.
class _Remote implements TalkRemoteDataSource {
  bool offline = false;
  final started = <Map<String, Object?>>[];
  final turns = <Map<String, Object?>>[];
  final ended = <Map<String, Object?>>[];

  void _reach() {
    if (offline) throw const NetworkException('connectionError');
  }

  @override
  Future<TalkHomeModel> getHome() async {
    _reach();
    return TalkHomeModel(_data('talk_ok'));
  }

  @override
  Future<ScenarioModel> getScenario(String id) async {
    _reach();
    return ScenarioModel(_data('talk_scenario_ok'));
  }

  @override
  Future<void> start(Map<String, Object?> request) async {
    _reach();
    started.add(request);
  }

  @override
  Future<TalkReplyModel> say(
    String conversationId,
    Map<String, Object?> request,
  ) async {
    turns.add(request);
    _reach();
    return TalkReplyModel(_data('talk_turn_ok'));
  }

  @override
  Future<void> end(String conversationId, Map<String, Object?> request) async {
    _reach();
    ended.add(request);
  }

  @override
  Future<TalkNotesModel> notes(String conversationId) async {
    _reach();
    return TalkNotesModel(_data('talk_notes_ok'));
  }
}

void main() {
  group('the models', () {
    test('the tab: units, scenarios and today\'s count', () {
      final home = TalkHomeModel(_data('talk_ok')).toEntity();

      expect(home.quotaLeft, 2);
      expect(home.quotaTotal, 3);
      expect(home.units, hasLength(3));
      final first = home.units.first.scenarios.first;
      expect(first.character.name, 'Jake');
      expect(first.taskCount, 3);
      expect(first.kind, TalkKind.ai);
      expect(first.bestDone, isNull);
      expect(home.units[1].scenarios.single.kind, TalkKind.written);
      expect(home.units.last.scenarios.single.locked, isTrue);
    });

    test('one that can\'t be read is left out, and the rest show', () {
      final json = _data('talk_ok');
      final units = [...json.readList('units')!];
      final unit = asJsonMap(units.first);
      final scenarios = [...unit.readList('scenarios')!];
      scenarios[0] = {...asJsonMap(scenarios[0])}..remove('title');
      units[0] = {...unit, 'scenarios': scenarios};

      final home = TalkHomeModel({...json, 'units': units}).toEntity();

      expect(home.units.first.scenarios, hasLength(1));
    });

    test('a scenario: intro, role, tasks, opening and suggestions', () {
      final scenario = ScenarioModel(_data('talk_scenario_ok')).toEntity();

      expect(scenario.character.description, isNotEmpty);
      expect(scenario.intro.audioUrl, isNotNull);
      expect(scenario.tasks, hasLength(3));
      expect(scenario.maxTurns, 7);
      expect(scenario.opening.english, 'Hey! Where do you want these boxes?');
      expect(scenario.suggestions, hasLength(2));
    });

    test('without max turns, the panel\'s default', () {
      final json = _data('talk_scenario_ok')..remove('maxTurns');

      expect(ScenarioModel(json).toEntity().maxTurns, 10);
    });

    test('a reply: the line, every task done so far, and what is left', () {
      final reply = TalkReplyModel(_data('talk_turn_ok')).toEntity();

      expect(reply.line.arabic, isNotEmpty);
      expect(reply.tasksDone, {'t_fragile'});
      expect(reply.turnsLeft, 6);
    });

    test(
      'a written scenario\'s script: a sentence, then replies to choose',
      () {
        final json = asJsonMap(
          asJsonMap(
            jsonDecode(
              File(TalkFakeDataSource.scenariosAsset).readAsStringSync(),
            ),
          )['sc_how_much'],
        );

        final scenario = ScenarioModel(json).toEntity();

        expect(scenario.kind, TalkKind.written);
        final repeat = scenario.script.first as RepeatTurn;
        expect(repeat.sentence.english, 'How much is this bag?');
        expect(repeat.taskId, 't_price');
        final choose = scenario.script[1] as ChooseTurn;
        expect(choose.options, hasLength(3));
        expect(choose.options.first.taskId, 't_buy');
        expect(choose.options[1].taskId, isNull);
      },
    );

    test('the notes: what was said, the better form and its concept', () {
      final notes = TalkNotesModel(_data('talk_notes_ok')).toEntity();

      expect(notes.status, NotesStatus.ready);
      expect(notes.notes, hasLength(2));
      final first = notes.notes.first;
      expect(first.turn, 0);
      expect(first.fix, 'Please put it down slowly.');
      expect(
        first.sentence,
        'Jake, this box is very fragile. Please put it down slowly.',
      );
      expect(first.concept, isNotEmpty);
    });

    test('no more than three notes, and still coming when unknown', () {
      final json = _data('talk_notes_ok');
      final note = asJsonMap(json.readList('notes')!.first);

      final many = TalkNotesModel({
        'status': 'ready',
        'notes': [note, note, note, note],
      }).toEntity();
      final waiting = const TalkNotesModel({'status': 'making'}).toEntity();

      expect(many.notes, hasLength(3));
      expect(waiting.status, NotesStatus.pending);
    });

    test('a turn goes with its id and how it was said', () {
      expect(talkTurnToJson(turnId: 't1', text: 'Hi', via: SaidVia.keyboard), {
        'turnId': 't1',
        'text': 'Hi',
        'via': 'keyboard',
      });
    });
  });

  group('the data source', () {
    test('where the contract says', () async {
      final adapter = FakeHttpAdapter(
        (options) => FakeResponse(
          200,
          body: switch (options.path) {
            '/api/v1/app/talk' => _body('talk_ok'),
            '/api/v1/app/talk/scenarios/sc_fragile_box' => _body(
              'talk_scenario_ok',
            ),
            '/api/v1/app/talk/conversations/c1/turns' => _body('talk_turn_ok'),
            '/api/v1/app/talk/conversations/c1/notes' => _body('talk_notes_ok'),
            _ => {'statusCode': 200},
          },
        ),
      );
      final remote = TalkRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      );

      await remote.getHome();
      await remote.getScenario('sc_fragile_box');
      await remote.start({'conversationId': 'c1'});
      final reply = await remote.say('c1', {'turnId': 't1'});
      await remote.end('c1', {'tasksDone': <String>[]});
      final notes = await remote.notes('c1');

      expect(reply.toEntity().tasksDone, isNotEmpty);
      expect(notes.toEntity().notes, hasLength(2));
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /api/v1/app/talk',
        'GET /api/v1/app/talk/scenarios/sc_fragile_box',
        'POST /api/v1/app/talk/conversations',
        'POST /api/v1/app/talk/conversations/c1/turns',
        'POST /api/v1/app/talk/conversations/c1/end',
        'GET /api/v1/app/talk/conversations/c1/notes',
      ]);
    });
  });

  group('the repository', () {
    late _Remote remote;
    late SettingsStorageService settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsStorageService(await SharedPreferences.getInstance());
      remote = _Remote();
    });

    TalkRepositoryImpl repository() => TalkRepositoryImpl(remote, settings);

    test('the scenarios are kept, and show offline', () async {
      await repository().getHome();
      remote.offline = true;

      final result = await repository().getHome();

      expect((result as Ok<TalkHome>).value.units, hasLength(3));
    });

    test('offline with nothing kept, it says so', () async {
      remote.offline = true;

      final result = await repository().getHome();

      expect((result as Err<TalkHome>).failure, isA<NetworkFailure>());
    });

    test('a conversation starts with an id the app made', () async {
      final result = await repository().start('sc_fragile_box');

      final id = (result as Ok<String>).value;
      expect(remote.started.single, {
        'conversationId': id,
        'scenarioId': 'sc_fragile_box',
      });
    });

    test('a turn sent again keeps its id; the next has its own', () async {
      final subject = repository();
      remote.offline = true;
      await subject.say('c1', turn: 0, text: 'Hi', via: SaidVia.mic);
      remote.offline = false;
      await subject.say('c1', turn: 0, text: 'Hi', via: SaidVia.mic);
      await subject.say('c1', turn: 1, text: 'Bye', via: SaidVia.mic);

      final ids = remote.turns.map((t) => t['turnId']).toList();
      expect(ids[0], ids[1]);
      expect(ids[2], isNot(ids[0]));
    });

    test('ending sends the tasks done', () async {
      await repository().end('c1', tasksDone: {'t_price'});

      expect(remote.ended.single, {
        'tasksDone': ['t_price'],
      });
    });

    test('the notes can\'t be reached: it says so', () async {
      remote.offline = true;

      final result = await repository().notes('c1');

      expect((result as Err<TalkNotes>).failure, isA<NetworkFailure>());
    });

    test('signing out forgets them', () async {
      final subject = repository();
      await subject.getHome();

      await settings.clearAccountData();

      expect(subject.keptHome, isNull);
    });
  });
}
