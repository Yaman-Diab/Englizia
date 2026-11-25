import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/unit_test_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/server_unit.dart';
import 'package:englizia/features/lessons/data/models/unit_test_model.dart';
import 'package:englizia/features/lessons/data/repositories/unit_test_repository_impl.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/unit_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_http_adapter.dart';

/// A test in the server's shape (the backend's note B-33b): the mock's asset,
/// whose `mockKey` and `mockLevels` only the mock reads. The dev server has
/// no published test yet to save a real answer of.
Map<String, Object?> _test() {
  final json = asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(UnitTestFakeDataSource.asset).readAsStringSync()),
    ),
  )..remove('mockLevels');
  for (final question in json.readList('questions')!) {
    asJsonMap(question).remove('mockKey');
  }
  return json;
}

/// The note's own example: a matching whose right side came as
/// `[sun, cat, dog]`.
Map<String, Object?> _matching() => {
  'id': 'ut',
  'versionId': 'v1',
  'versionNo': 1,
  'questionCount': 1,
  'passPercent': 70,
  'state': 'available',
  'questions': [
    {
      'versionId': 'm',
      'template': 'matching',
      'instructionAr': 'طابق',
      'body': {
        'rightKind': 'text',
        'left': ['cat', 'dog', 'sun'],
        'right': [
          {'text': 'sun'},
          {'text': 'cat'},
          {'text': 'dog'},
        ],
      },
    },
  ],
  'media': const <String, Object?>{},
};

void main() {
  group('the test', () {
    late UnitTest unitTest;

    setUp(() => unitTest = UnitTestModel(_test()).toEntity('seed'));

    test('reads with its state and its questions', () {
      expect(unitTest.id, 'ut_mock');
      expect(unitTest.versionId, 'ut_mock_v1');
      expect(unitTest.status.state, UnitTestState.available);
      expect(unitTest.status.questionCount, 5);
      expect(unitTest.status.passPercent, 70);
      expect(unitTest.questions.map((q) => q.runtimeType), [
        MultipleChoiceExercise,
        FillChoicesExercise,
        WordOrderExercise,
        MatchingExercise,
        MultipleChoiceExercise,
      ]);
      expect(unitTest.questions.every((q) => q.hint == null), isTrue);
    });

    test('everything stays in the order it came: the learner’s own', () {
      final choice = unitTest.questions[0] as MultipleChoiceExercise;
      final fill = unitTest.questions[1] as FillChoicesExercise;
      final order = unitTest.questions[2] as WordOrderExercise;
      final match = unitTest.questions[3] as MatchingExercise;

      expect(choice.options.map((o) => o.id), ['a', 'b', 'c']);
      expect(fill.bank.map((c) => c.text), ['feed', 'feeds', 'feeding']);
      expect(order.bank.map((c) => c.text), [
        'in',
        'The',
        'barn.',
        'the',
        'is',
        'cow',
        'are',
      ]);
      expect(match.wordsShown.map((p) => p.id), ['cow', 'egg', 'field']);
      expect(match.meaningsShown.map((p) => p.meaning), [
        'حقل',
        'بقرة',
        'بيضة',
      ]);
    });

    test('an order of words may be sent with any number of cards', () {
      final order = unitTest.questions[2] as WordOrderExercise;

      expect(
        SequenceDraft([
          order.bank.first,
        ], needed: order.answerWords.length).isComplete,
        isTrue,
      );
    });

    test('a matching goes as the places of what each word was put with', () {
      final model = UnitTestModel(_matching());
      final match = model.toEntity('s').questions.single as MatchingExercise;
      // The pairs stand for the places as they came: sun 0, cat 1, dog 2.
      final byRight = {for (final pair in match.pairs) pair.meaning: pair.id};

      final body = model.submission({
        'm': LinksDraft(
          total: 3,
          links: {
            'cat': byRight['cat']!,
            'dog': byRight['dog']!,
            'sun': byRight['sun']!,
          },
        ),
      }, submissionId: 'sub-1');

      expect(body, {
        'clientSubmissionId': 'sub-1',
        'versionId': 'v1',
        'answers': [
          {
            'questionVersionId': 'm',
            'answer': {
              'pairs': [1, 2, 0],
            },
          },
        ],
      });
    });

    test('each answer in the server’s form, cards by their text', () {
      final model = UnitTestModel(_test());
      final fill = unitTest.questions[1] as FillChoicesExercise;
      final order = unitTest.questions[2] as WordOrderExercise;

      final answers =
          model.submission({
                'utq_01': const ChoiceDraft('b'),
                'utq_02': SlotsDraft([fill.bank[1]]),
                'utq_03': SequenceDraft([
                  order.bank[1],
                  order.bank[5],
                ], needed: 1),
              }, submissionId: 's')['answers']!
              as List<Object?>;

      expect(answers, [
        {
          'questionVersionId': 'utq_01',
          'answer': {'optionId': 'b'},
        },
        {
          'questionVersionId': 'utq_02',
          'answer': {
            'gaps': ['feeds'],
          },
        },
        {
          'questionVersionId': 'utq_03',
          'answer': {
            'chips': ['The', 'cow'],
          },
        },
      ]);
    });
  });

  group('the result', () {
    test('marks, the wait after a fail, and no level suggested', () {
      final result = unitTestResultFromJson(const {
        'correct': 3,
        'questionCount': 5,
        'percent': 60,
        'passed': false,
        'retryAvailableAt': '2026-11-24T09:04:23.469Z',
        'bestPercent': 60,
        'questions': [
          {'questionVersionId': 'a', 'isCorrect': true},
          {'questionVersionId': 'b', 'isCorrect': false},
        ],
        'levelCheck': null,
      }, passPercent: 70);

      expect(result.passed, isFalse);
      expect(result.percent, 60);
      expect(result.passPercent, 70);
      expect(result.retryAt, DateTime.utc(2026, 11, 24, 9, 4, 23, 469));
      expect(result.marks, [true, false]);
      expect(result.suggestion, isNull);
    });

    test('a level suggested, named as the map names levels', () {
      final suggestion = levelSuggestionFromJson(const {
        'id': 'lc',
        'direction': 'up',
        'percent': 100,
        'level': {'id': 'l1', 'nameAr': 'A2 ما قبل المتوسط', 'cefrCode': 'a2'},
        'suggestedLevel': {
          'id': 'l2',
          'nameAr': 'B1 المتوسط',
          'cefrCode': 'b1',
        },
      })!;

      expect(suggestion.up, isTrue);
      expect(suggestion.percent, 100);
      expect(suggestion.level.label, 'A2');
      expect(suggestion.suggested.label, 'B1');
      expect(suggestion.suggested.name, 'المتوسط');
    });

    test('a check that suggests no move is no suggestion', () {
      expect(
        levelSuggestionFromJson(const {
          'id': 'lc',
          'direction': 'none',
          'percent': 70,
          'level': {'id': 'l1', 'nameAr': 'A2', 'cefrCode': 'a2'},
          'suggestedLevel': {'id': 'l1', 'nameAr': 'A2', 'cefrCode': 'a2'},
        }),
        isNull,
      );
    });
  });

  group('the map', () {
    test('a unit’s test is its last stone; its lessons don’t count it', () {
      final unit = <String, Object?>{
        'lessons': [
          {
            'id': 'l1',
            'type': 'grammar_video',
            'titleAr': 'a',
            'state': 'completed',
          },
        ],
        'test': {'id': 't1', 'state': 'passed', 'questionCount': 5},
      };

      expect(lessonsFromMap(unit).last, {
        'id': 't1',
        'kind': 'unitReview',
        'title': '',
        'done': true,
      });
      expect(lessonsFromMap(unit, test: false), hasLength(1));
      expect(lessonsFromMap({...unit, 'test': null}), hasLength(1));
    });
  });

  group('the calls', () {
    late Map<String, FakeResponse> answers;
    late FakeHttpAdapter adapter;
    late UnitTestRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      answers = {
        '/api/v1/app/unit-tests/ut_mock': FakeResponse(
          200,
          body: {'statusCode': 200, 'data': _test()},
        ),
      };
      adapter = FakeHttpAdapter(
        (request) => answers[request.path] ?? const FakeResponse(500, body: {}),
      );
      repository = UnitTestRepositoryImpl(
        UnitTestRemoteDataSourceImpl(
          ApiClient(
            Dio(BaseOptions(baseUrl: 'https://api.test'))
              ..httpClientAdapter = adapter,
          ),
        ),
        settings: SettingsStorageService(await SharedPreferences.getInstance()),
      );
    });

    Future<UnitTest> read() async =>
        ((await repository.getTest('ut_mock')) as Ok<UnitTest>).value;

    test('the whole test goes at once, and its result comes back', () async {
      final unitTest = await read();
      answers['/api/v1/app/unit-tests/ut_mock/submissions'] =
          const FakeResponse(
            200,
            body: {
              'statusCode': 200,
              'data': {
                'correct': 1,
                'questionCount': 1,
                'percent': 100,
                'passed': true,
                'questions': [
                  {'questionVersionId': 'utq_01', 'isCorrect': true},
                ],
              },
            },
          );

      final result = await repository.submit(unitTest, {
        'utq_01': const ChoiceDraft('b'),
      }, submissionId: 'sub-1');

      final sent = adapter.requests.last;
      expect(sent.method, 'POST');
      expect(sent.path, '/api/v1/app/unit-tests/ut_mock/submissions');
      expect((sent.data! as Map)['clientSubmissionId'], 'sub-1');
      expect((result as Ok<UnitTestResult>).value.passed, isTrue);
    });

    test(
      'too soon after a fail is a wait, as long as the server says',
      () async {
        final unitTest = await read();
        answers['/api/v1/app/unit-tests/ut_mock/submissions'] =
            const FakeResponse(
              422,
              body: {
                'statusCode': 422,
                'error': {'code': 'unit_test.retry_not_yet'},
              },
              headers: {
                'retry-after': ['120'],
              },
            );

        final result = await repository.submit(
          unitTest,
          const {},
          submissionId: 's',
        );

        expect(
          result,
          isA<Err<UnitTestResult>>().having(
            (e) => e.failure,
            'failure',
            isA<RateLimitFailure>().having(
              (f) => f.retryAfter,
              'wait',
              const Duration(minutes: 2),
            ),
          ),
        );
      },
    );

    test('a level’s choice goes as move', () async {
      answers['/api/v1/app/level-checks/lc/choose'] = const FakeResponse(
        200,
        body: {'statusCode': 200, 'data': <String, Object?>{}},
      );

      expect(await repository.chooseLevel('lc', move: true), isA<Ok<void>>());
      expect(adapter.requests.last.data, {'move': true});
    });
  });
}
