import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/models/placement_models.dart';
import 'package:englizia/features/placement/data/repositories/placement_repository_impl.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';

Map<String, Object?> data(String fixture) =>
    asJsonMap(ApiClient.unwrap(apiFixture(fixture)));

const _track = '01a1f24f-ea3e-7693-b3a7-a60061ac9a53';

ApiException _apiError(String fixture) {
  final body = apiFixture(fixture);
  return ApiException.fromResponse(
    statusCode: body['statusCode']! as int,
    body: body,
  );
}

/// The server as the tests need it: answers from the dev server's fixtures,
/// and what was asked.
class _Server implements PlacementRemoteDataSource {
  String? active = _track;
  Map<String, Object?> state = data('app_placement_available');
  Map<String, Object?> started = data('app_placement_session_stage_1');
  Map<String, Object?> afterStage = data('app_placement_session_stage_2');
  Map<String, Object?> session = data('app_placement_session_stage_2');
  Object? stageError;
  Object? stateError;
  final chooseErrors = <Object>[];

  final stateFor = <String>[];
  final startedFor = <String>[];
  final sessionsRead = <String>[];
  final submitted = <(int, List<Map<String, Object?>>)>[];
  final chosen = <(String, String, String)>[];

  @override
  Future<String?> activeTrackId() async => active;

  @override
  Future<PlacementStateModel> getState(String trackId) async {
    stateFor.add(trackId);
    if (stateError case final error?) throw error;
    return PlacementStateModel(state);
  }

  @override
  Future<PlacementSessionModel> startSession(String trackId) async {
    startedFor.add(trackId);
    return PlacementSessionModel(started);
  }

  @override
  Future<PlacementSessionModel> getSession(String sessionId) async {
    sessionsRead.add(sessionId);
    return PlacementSessionModel(session);
  }

  @override
  Future<PlacementSessionModel> submitStage(
    String sessionId,
    int stage,
    List<Map<String, Object?>> answers,
  ) async {
    submitted.add((stage, answers));
    if (stageError case final error?) throw error;
    return PlacementSessionModel(afterStage);
  }

  @override
  Future<void> choose(String sessionId, String trackId, String choice) async {
    chosen.add((sessionId, trackId, choice));
    if (chooseErrors.isNotEmpty) throw chooseErrors.removeAt(0);
  }
}

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  final now = DateTime.utc(2026, 11, 20, 13);

  group('the state (GET /api/v1/app/placement)', () {
    test('available: what the test takes', () {
      final state = PlacementStateModel(data('app_placement_available'));
      expect(state.unavailable, isFalse);
      expect(
        state.summary,
        const PlacementSummary(
          minMinutes: 11,
          maxMinutes: 15,
          stages: 2,
          mayAddStage: true,
        ),
      );
      expect(
        state.status(now: now, answered: (_, _) => 0),
        const PlacementNotTaken(),
      );
    });

    test('in progress: the stage, and the question the phone got to', () {
      final state = PlacementStateModel(data('app_placement_in_progress'));
      expect(
        state.status(
          now: now,
          answered: (session, stage) =>
              session == '01a1f8ee-ac11-702b-ab34-4fe1c8c95017' && stage == 2
              ? 4
              : 0,
        ),
        const PlacementInProgress(stage: 2, question: 5),
      );
    });

    test('a result waiting for the choice', () {
      final state = PlacementStateModel(data('app_placement_result'));
      expect(
        state.status(now: now, answered: (_, _) => 0),
        const PlacementAwaitingChoice(
          attemptId: '01a1f8ee-ac11-702b-ab34-4fe1c8c95017',
        ),
      );
    });

    test('done: the retake waits its 30 days, then opens', () {
      final state = PlacementStateModel(data('app_placement_done'));
      expect(
        state.status(now: now, answered: (_, _) => 0),
        const PlacementRetakeLocked(daysLeft: 30),
      );
      expect(
        state.status(now: DateTime.utc(2026, 12, 21), answered: (_, _) => 0),
        const PlacementRetakeOpen(level: 'Pre-A1', daysAgo: 30),
      );
    });

    test('a retake open: the last result and how long ago', () {
      final json = data('app_placement_result')
        ..['state'] = 'available'
        ..['isRetake'] = true;
      expect(
        PlacementStateModel(
          json,
        ).status(now: DateTime.utc(2026, 11, 30), answered: (_, _) => 0),
        const PlacementRetakeOpen(level: 'Pre-A1', daysAgo: 9),
      );
    });

    test('the result on the ladder, from the track\'s own levels', () {
      final result = PlacementStateModel(data('app_placement_result')).result;

      expect(result.levels.map((l) => l.code), [
        'Pre-A1',
        'A1',
        'A2',
        'B1',
        'B2',
      ]);
      // Pre-A1 measured; the track starts the learner at its first level.
      expect(result.levelIndex, 0);
      expect(result.levels.first.id, '01a1f24f-ea3e-7f94-9d61-e30272387f0a');
      expect(result.levels.first.name.of('en'), 'A1 Beginner');
      expect(result.canLower, isFalse);
      expect(result.skills.map((s) => (s.kind, s.score)), [
        (PlacementSkillKind.vocabulary, .86),
        (PlacementSkillKind.grammar, 0.0),
        (PlacementSkillKind.reading, 0.0),
        (PlacementSkillKind.listening, 0.0),
      ]);
    });

    test('a lower level to start from, when the track has one', () {
      final json = data('app_placement_result');
      final result = asJsonMap(json['result'])
        ..['cefr'] = 'a2'
        ..['lowerLevel'] = {
          'id': 'lvl-a1',
          'nameAr': 'المستوى الثاني',
          'nameEn': 'A1',
          'cefrCode': 'a1',
          'gradeNumber': null,
        };
      json['result'] = result;
      final placed = PlacementStateModel(json).result;
      expect(placed.levelIndex, 2);
      expect(placed.canLower, isTrue);
      expect(placed.levels[1].id, 'lvl-a1');
      expect(placed.levels[1].name.of('ar'), 'المستوى الثاني');
      // A step the learner can't start at has no id.
      expect(placed.levels[3].id, isEmpty);
    });
  });

  group('a session', () {
    test('the questions as the screen shows them', () {
      final session = PlacementSessionModel(
        data('app_placement_session_stage_1'),
      );
      final questions = session.questions('seed');

      expect(session.stage, 1);
      expect(questions, hasLength(12));
      final vocabulary = questions.first;
      expect(vocabulary.kind, PlacementQuestionKind.vocabulary);
      expect(vocabulary.instruction, 'اختر الكلمة المناسبة');
      expect(vocabulary.before, '[demo] a·routing 1. I drink ');
      expect(vocabulary.after, ' every morning.');
      expect(vocabulary.ask, isEmpty);

      final reading = questions[2];
      expect(reading.kind, PlacementQuestionKind.reading);
      expect(reading.passage, startsWith('The meeting moved'));
      expect(reading.ask, contains('When is the meeting now?'));

      final listening = questions[3];
      expect(listening.kind, PlacementQuestionKind.listening);
      expect(
        listening.audioUrl,
        startsWith('https://api-dev.engleazia.com/media/'),
      );
      expect(listening.maxPlays, 2);
      expect(vocabulary.maxPlays, 0);
    });

    test('each learner\'s own order of the options, the same each time', () {
      final session = PlacementSessionModel(
        data('app_placement_session_stage_1'),
      );
      List<String> order(String seed) => [
        for (final o in session.questions(seed).first.options) o.id,
      ];

      expect(order('one'), order('one'));
      expect(order('one').toSet(), {'a', 'b', 'c', 'd'});
      final seeds = ['one', 'two', 'three', 'four', 'five', 'six'];
      expect({for (final s in seeds) order(s).join()}.length, greaterThan(1));
    });

    test('what follows a stage: the next one, or the end', () {
      final next = PlacementSessionModel(
        data('app_placement_session_stage_2'),
      ).next;
      expect(
        next,
        const PlacementNextStage(
          stage: 2,
          questionCount: 15,
          listeningCount: 4,
          deciding: false,
        ),
      );
      expect(
        PlacementSessionModel(data('app_placement_session_completed')).next,
        isNull,
      );
    });

    test('a question it can\'t show is refused', () {
      final json = data('app_placement_session_stage_1');
      final first = asJsonMap((json['questions']! as List).first)
        ..['template'] = 'word_order';
      (json['questions']! as List)[0] = first;
      expect(
        () => PlacementSessionModel(json).questions(''),
        throwsFormatException,
      );
    });
  });

  group('the requests', () {
    late FakeHttpAdapter adapter;
    PlacementRemoteDataSourceImpl source(FakeResponse Function() answer) {
      adapter = FakeHttpAdapter((_) => answer());
      return PlacementRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      );
    }

    test('GET /api/v1/app/placement?trackId=', () async {
      final state = await source(
        () => FakeResponse(200, body: apiFixture('app_placement_available')),
      ).getState(_track);
      final request = adapter.requests.single;
      expect(request.path, '/api/v1/app/placement');
      expect(request.query, {'trackId': _track});
      expect(state.state, 'available');
    });

    test('POST /api/v1/app/placement/sessions', () async {
      final session = await source(
        () => FakeResponse(
          201,
          body: apiFixture('app_placement_session_stage_1'),
        ),
      ).startSession(_track);
      final request = adapter.requests.single;
      expect(
        (request.method, request.path),
        ('POST', '/api/v1/app/placement/sessions'),
      );
      expect(request.data, {'trackId': _track});
      expect(session.stage, 1);
    });

    test(
      'GET and POST a stage of /api/v1/app/placement/sessions/{id}',
      () async {
        final server = source(
          () => FakeResponse(
            200,
            body: apiFixture('app_placement_session_stage_2'),
          ),
        );
        await server.getSession('s-1');
        await server.submitStage('s-1', 1, [
          {'questionId': 'q', 'optionId': 'b'},
        ]);
        expect(adapter.requests.map((r) => (r.method, r.path)), [
          ('GET', '/api/v1/app/placement/sessions/s-1'),
          ('POST', '/api/v1/app/placement/sessions/s-1/stages/1'),
        ]);
        expect(adapter.requests.last.data, {
          'answers': [
            {'questionId': 'q', 'optionId': 'b'},
          ],
        });
      },
    );

    test('POST …/choose, and the active track from the enrollments', () async {
      await source(
        () =>
            FakeResponse(200, body: apiFixture('app_placement_choose_result')),
      ).choose('s-1', _track, 'lower');
      expect(
        adapter.requests.single.path,
        '/api/v1/app/placement/sessions/s-1/choose',
      );
      expect(adapter.requests.single.data, {
        'trackId': _track,
        'choice': 'lower',
      });

      final active = await source(
        () => FakeResponse(
          200,
          body: {
            'statusCode': 200,
            'data': {
              'items': [
                data('app_enrollments_join_placement')..['isActive'] = false,
                {...data('app_enrollments_join_placement'), 'trackId': 't-2'},
              ],
            },
            'error': null,
          },
        ),
      ).activeTrackId();
      expect(adapter.requests.single.path, '/api/v1/app/enrollments');
      expect(active, 't-2');
      expect(
        await source(
          () => FakeResponse(200, body: apiFixture('app_enrollments_empty')),
        ).activeTrackId(),
        isNull,
      );
    });

    test('the server\'s refusals keep their codes', () {
      expect(
        _apiError('app_placement_retake_not_yet').code,
        'placement.retake_not_yet',
      );
      expect(_apiError('app_placement_stage_missing_answer').statusCode, 400);
      expect(
        _apiError('app_placement_choose_no_lower_level').code,
        'placement.no_lower_level',
      );
    });
  });

  group('PlacementRepositoryImpl', () {
    late SettingsStorageService settings;
    late _Server server;
    var signedIn = true;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsStorageService(await SharedPreferences.getInstance());
      server = _Server();
      signedIn = true;
    });

    PlacementRepositoryImpl repository() => PlacementRepositoryImpl(
      server,
      settings: settings,
      hasSession: () async => signedIn,
      now: () => now,
    );

    test('no account yet: nothing is asked', () async {
      signedIn = false;
      final result = await repository().getSummary();
      expect((result as Err).failure, isA<UnauthorizedFailure>());
      expect(server.stateFor, isEmpty);
    });

    test('the track: the one given, else the active one', () async {
      final subject = repository();
      await subject.getSummary();
      expect(server.stateFor, [_track]);

      subject.useTrack('t-other');
      await subject.getSummary();
      expect(server.stateFor.last, 't-other');

      server.active = null;
      final none = repository();
      final result = await none.getStatus();
      expect((result as Err).failure, isA<NotFoundFailure>());
    });

    test('the summary and the status, from one request', () async {
      final subject = repository();
      final (summary, status) = await (
        subject.getSummary(),
        subject.getStatus(),
      ).wait;
      expect(summary, isA<Ok<PlacementSummary>>());
      expect(status, const Ok<PlacementStatus>(PlacementNotTaken()));
      expect(server.stateFor, hasLength(1));
    });

    test('a track with no test: nothing of it is shown', () async {
      server.state = {...server.state, 'state': 'unavailable'};
      final result = await repository().getSummary();
      expect((result as Err).failure, isA<NotFoundFailure>());
    });

    test('no connection: the status kept from before', () async {
      server.state = data('app_placement_done');
      await repository().getStatus();
      server.stateError = const NetworkException('connectionError');

      final offline = await repository().getStatus();
      expect(
        offline,
        const Ok<PlacementStatus>(PlacementRetakeLocked(daysLeft: 30)),
      );
    });

    test('a stage: kept on the phone, then sent whole when it ends', () async {
      final subject = repository();
      final attempt =
          (await subject.startAttempt() as Ok<PlacementAttempt>).value;
      expect(attempt.stage, 1);
      expect(attempt.answered, 0);
      expect(server.startedFor, [_track]);

      final questions =
          (await subject.getStage(attempt.id, 1) as Ok<List<PlacementQuestion>>)
              .value;
      expect(
        server.sessionsRead,
        isEmpty,
        reason: 'its questions came with it',
      );
      for (final (i, question) in questions.indexed) {
        await subject.saveAnswer(
          PlacementAnswer(
            attemptId: attempt.id,
            stage: 1,
            questionId: question.id,
            optionId: i == 0 ? null : 'a',
            plays: 0,
          ),
        );
      }
      expect(subject.unsentAnswers(attempt.id, 1), 12);
      expect(server.submitted, isEmpty);

      final next = await subject.completeStage(attempt.id, 1);
      expect((next as Ok<PlacementNextStage?>).value?.stage, 2);
      final (stage, answers) = server.submitted.single;
      expect(stage, 1);
      expect(answers, hasLength(12));
      expect(answers.first, {
        'questionId': questions.first.id,
        'dontKnow': true,
      });
      expect(answers[1], {'questionId': questions[1].id, 'optionId': 'a'});
      expect(subject.unsentAnswers(attempt.id, 1), 0);

      // The next stage's questions came with the answer.
      await subject.getStage(attempt.id, 2);
      expect(server.sessionsRead, isEmpty);
    });

    test('an answer given again replaces the first', () async {
      final subject = repository();
      const answer = PlacementAnswer(
        attemptId: 's',
        stage: 1,
        questionId: 'q',
        optionId: 'a',
        plays: 0,
      );
      await subject.saveAnswer(answer);
      await subject.saveAnswer(
        const PlacementAnswer(
          attemptId: 's',
          stage: 1,
          questionId: 'q',
          optionId: 'c',
          plays: 0,
        ),
      );
      expect(subject.unsentAnswers('s', 1), 1);
    });

    test('a stage that ends with no connection keeps its answers', () async {
      final subject = repository();
      final attempt =
          (await subject.startAttempt() as Ok<PlacementAttempt>).value;
      await subject.saveAnswer(
        PlacementAnswer(
          attemptId: attempt.id,
          stage: 1,
          questionId: 'q',
          optionId: 'a',
          plays: 0,
        ),
      );
      server.stageError = const NetworkException('connectionError');

      final result = await subject.completeStage(attempt.id, 1);
      expect((result as Err).failure, isA<NetworkFailure>());
      expect(repository().unsentAnswers(attempt.id, 1), 1);
    });

    test('a stage sent before: the session says where it stands', () async {
      final subject = repository();
      server.stageError = const ApiException(
        statusCode: 409,
        code: 'placement.stage_not_current',
      );
      final result = await subject.completeStage('s', 1);
      expect((result as Ok<PlacementNextStage?>).value?.stage, 2);
      expect(server.sessionsRead, ['s']);

      server.session = data('app_placement_session_completed');
      expect(
        await subject.completeStage('s', 2),
        const Ok<PlacementNextStage?>(null),
      );
    });

    test('the last stage: the result, from the track\'s state', () async {
      final subject = repository();
      server.afterStage = data('app_placement_session_completed');
      final done = await subject.completeStage('s', 2);
      expect(done, const Ok<PlacementNextStage?>(null));

      server.state = data('app_placement_result');
      final result = await subject.getResult('s');
      expect((result as Ok<PlacementResult>).value.levelIndex, 0);
      expect(settings.placementProgress, isNull);
    });

    test('carrying on: the answers kept count, and the bar\'s sizes', () async {
      final subject = repository();
      await subject.getStatus();
      server.started = data('app_placement_session_stage_2');
      final sessionId = server.started['id']! as String;
      await subject.saveAnswer(
        PlacementAnswer(
          attemptId: sessionId,
          stage: 2,
          questionId: 'q',
          optionId: 'a',
          plays: 0,
        ),
      );

      final attempt =
          (await subject.startAttempt() as Ok<PlacementAttempt>).value;
      expect((attempt.stage, attempt.answered), (2, 1));
      // Stage 2 has 15 of the test's 27: the first had the other 12.
      expect(attempt.stageSizes, [12, 15]);
    });

    test(
      'listens are kept on the phone, as the server never hears of them',
      () async {
        final subject = repository();
        await subject.savePlays('s', 'q', 2);
        expect(repository().playsUsed('s', 'q'), 2);
        expect(repository().playsUsed('other', 'q'), 0);
      },
    );

    test('«ابدأ من …»: the result, or the level below', () async {
      final subject = repository();
      expect(
        await subject.acceptLevel('s', lower: false),
        const Ok<void>(null),
      );
      expect(await subject.acceptLevel('s', lower: true), const Ok<void>(null));
      expect(server.chosen, [('s', _track, 'result'), ('s', _track, 'lower')]);
    });

    test(
      'an older session than the latest result chooses the latest',
      () async {
        server
          ..state = data('app_placement_result')
          ..chooseErrors.add(
            const ApiException(
              statusCode: 409,
              code: 'placement.session_not_latest',
            ),
          );
        final result = await repository().acceptLevel('old', lower: false);
        expect(result, const Ok<void>(null));
        expect(server.chosen.map((c) => c.$1), [
          'old',
          '01a1f8ee-ac11-702b-ab34-4fe1c8c95017',
        ]);
      },
    );

    test('something broken on the phone counts as nothing kept', () async {
      await settings.setPlacementProgress('not json');
      expect(repository().unsentAnswers('s', 1), 0);
    });

    test('putting the test off asks nothing', () async {
      expect(await repository().deferTest(), const Ok<void>(null));
      expect(server.stateFor, isEmpty);
    });
  });

  test('mock mode goes through a whole test', () async {
    final source = PlacementFakeDataSource(
      _DiskBundle(),
      latency: Duration.zero,
    );
    expect((await source.getState('t')).state, 'available');

    final started = await source.startSession('t');
    expect(started.stage, 1);
    expect((await source.getState('t')).state, 'in_progress');

    expect((await source.submitStage(started.id, 1, const [])).stage, 2);
    // The same stage again answers as the session stands.
    expect((await source.submitStage(started.id, 1, const [])).stage, 2);
    expect(
      (await source.submitStage(started.id, 2, const [])).completed,
      isTrue,
    );
    expect((await source.getState('t')).state, 'result');

    await source.choose(started.id, 't', 'result');
    expect((await source.getState('t')).state, 'done');
    expect(
      () => source.startSession('t'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'placement.retake_not_yet',
        ),
      ),
    );
  });
}
