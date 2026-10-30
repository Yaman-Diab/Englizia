import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/data/repositories/lesson_repository_impl.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';
import 'package:englizia/features/lessons/domain/services/stable_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';

class _Remote implements LessonRemoteDataSource {
  final sent = <Map<String, Object?>>[];
  final lessons = <String>[];
  var offline = false;
  ApiException? failWith;
  ApiException? refuseOnce;
  Map<String, Object?> lesson = sampleLessonJson();

  @override
  Future<LessonModel> getLesson(String lessonId) async {
    if (offline) throw const NetworkException('connectionError');
    if (failWith case final error?) throw error;
    return LessonModel(lesson);
  }

  @override
  Future<void> sendAnswer(String lessonId, Map<String, Object?> request) async {
    if (offline) throw const NetworkException('connectionError');
    if (refuseOnce case final error?) {
      refuseOnce = null;
      throw error;
    }
    lessons.add(lessonId);
    sent.add(request);
  }
}

const _attempt = ExerciseAttempt(
  lessonId: 'les',
  lessonVersion: 3,
  questionId: 'q1',
  draft: ChoiceDraft('o2'),
  hinted: true,
);

const _memberTokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

AppSessionController _session(SettingsStorageService settings) =>
    AppSessionController(tokens: FakeTokenStorage(), settings: settings);

Map<String, Object?> _question(Map<String, Object?> changes) => {
  'id': 'q',
  'template': 'multipleChoice',
  'instructionAr': 'a',
  'prompt': {'en': 'She ___ here.'},
  'options': [
    {'id': 'o1', 'text': 'x'},
  ],
  'answer': 'o1',
  ...changes,
};

Lesson _parse(List<Map<String, Object?>> exercises, {String seed = 's'}) =>
    LessonModel({
      'id': 'les',
      'version': 1,
      'exercises': exercises,
    }).toEntity(seed);

void main() {
  group('the example lesson', () {
    final lesson = LessonModel(sampleLessonJson()).toEntity('seed');

    test('has its version and each template', () {
      expect(lesson.version, 1);
      expect(lesson.exercises[0], isA<MultipleChoiceExercise>());
      expect(lesson.exercises[1], isA<ImageChoiceExercise>());
      expect(lesson.exercises[2], isA<ListenChooseExercise>());
      expect(lesson.exercises[3], isA<MultipleChoiceExercise>());
    });

    test('carries the sentence, its hint and its key', () {
      final first = lesson.exercises.first as MultipleChoiceExercise;
      expect(first.before, 'She');
      expect(first.after, 'to school every day.');
      expect(first.hint, contains('she'));
      expect(first.instruction, isNotEmpty);
      expect(first.answerId, 'o2');
      expect(first.options, hasLength(4));
    });

    test('names its pictures, and has no hint on them', () {
      final picture = lesson.exercises[1] as ImageChoiceExercise;
      expect(picture.word, 'barn');
      expect(picture.hint, isNull);
      expect(picture.clipUrl, isNotEmpty);
      final barn = picture.options.firstWhere((o) => o.id == 'o1');
      expect(barn.image, endsWith('.svg'));
      expect(barn.alt, isNotEmpty);
    });

    test('says where a question is in the book', () {
      expect(
        lesson.exercises.last.bookReference,
        const BookReference(page: 34, exercise: 2),
      );
      expect(lesson.exercises.first.bookReference, isNull);
    });

    test('a listening question plays by itself, and reports a failure', () {
      expect(lesson.exercises[2].autoplays, isTrue);
      expect(lesson.exercises[2].reportsClipFailure, isTrue);
      expect(lesson.exercises[1].autoplays, isFalse);
      expect(lesson.exercises[1].reportsClipFailure, isFalse);
    });
  });

  group('parsing', () {
    test('a template this version does not know is left out', () {
      final parsed = _parse([
        _question({'template': 'wordOrder'}),
        _question({}),
      ]);
      expect(parsed.exercises.map((q) => q.runtimeType), [
        MultipleChoiceExercise,
      ]);
    });

    test('a review-only question is not part of the lesson', () {
      expect(
        _parse([
          _question({'reviewOnly': true}),
        ]).exercises,
        isEmpty,
      );
    });

    test('a broken question is skipped, not the whole lesson', () {
      final parsed = _parse([
        _question({'options': <Object?>[]}),
        _question({'id': 'good'}),
      ]);
      expect(parsed.exercises.single.id, 'good');
    });

    for (final (name, broken) in <(String, Map<String, Object?>)>[
      (
        'no blank',
        {
          'prompt': {'en': 'She runs.'},
        },
      ),
      (
        'two blanks',
        {
          'prompt': {'en': 'She ___ and ___.'},
        },
      ),
      ('a right answer not among the options', {'answer': 'nope'}),
      ('no instruction', {'instructionAr': null}),
    ]) {
      test('$name is broken', () {
        final parsed = _parse([
          _question(broken),
          _question({'id': 'good'}),
        ]);
        expect(parsed.exercises.single.id, 'good');
      });
    }

    test('nothing readable at all is a format error', () {
      expect(
        () => _parse([
          _question({'options': <Object?>[]}),
        ]),
        throwsFormatException,
      );
    });

    test('a lesson with no version is a format error', () {
      expect(
        () => const LessonModel({
          'id': 'les',
          'exercises': <Object?>[],
        }).toEntity('s'),
        throwsFormatException,
      );
    });

    test('no exercises is an empty lesson', () {
      expect(_parse([]).exercises, isEmpty);
    });

    test('an attempt names the version, and its answer by kind', () {
      expect(attemptToJson(_attempt, 'a1'), {
        'attemptId': 'a1',
        'lessonVersion': 3,
        'questionId': 'q1',
        'answer': {'optionId': 'o2'},
        'hinted': true,
      });
    });
  });

  group('the order of the options', () {
    final options = _question({
      'options': [
        for (var i = 0; i < 8; i++) {'id': 'o$i', 'text': 't$i'},
      ],
    });

    List<String> order(String seed) {
      final exercise =
          _parse([options], seed: seed).exercises.single as ChoiceExercise;
      return [for (final o in exercise.options) o.id];
    }

    test('stays the same for one learner', () {
      expect(order('learner'), order('learner'));
    });

    test('differs between learners', () {
      expect(order('one'), isNot(order('another')));
    });

    test('is a shuffle, losing nothing', () {
      expect(order('one').toSet(), {for (var i = 0; i < 8; i++) 'o$i'});
    });

    test('takes an empty list', () {
      expect(stableOrder(<int>[], 'key'), isEmpty);
    });
  });

  group('marking', () {
    final exercise = sampleExercises().first;

    test('the right option is correct', () {
      expect(evaluate(exercise, const ChoiceDraft('o2')).correct, isTrue);
    });

    test('another option is wrong, and the right one is named', () {
      final result = evaluate(exercise, const ChoiceDraft('o1'));
      expect(result.correct, isFalse);
      expect(result, const ChoiceEvaluation(chosenId: 'o1', rightId: 'o2'));
    });
  });

  group('the endpoints', () {
    late FakeHttpAdapter adapter;
    late LessonRemoteDataSourceImpl source;

    setUp(() {
      adapter = FakeHttpAdapter(
        (_) => FakeResponse(
          200,
          body: {'statusCode': 200, 'data': sampleLessonJson()},
        ),
      );
      source = LessonRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      );
    });

    test('a lesson comes whole', () async {
      final model = await source.getLesson('les');

      expect(adapter.requests.single.path, '/api/v1/app/lessons/les');
      expect(model.toEntity('s').exercises, hasLength(4));
    });

    test('an answer goes to its lesson, with its attempt id', () async {
      await source.sendAnswer('les', {'attemptId': 'a1'});

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/app/lessons/les/answers');
      expect(request.data, {'attemptId': 'a1'});
    });
  });

  group('the repository', () {
    late _Remote remote;
    late SettingsStorageService settings;
    late LessonRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsStorageService(await SharedPreferences.getInstance());
      remote = _Remote();
      repository = LessonRepositoryImpl(remote, settings: settings);
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    List<Object?> unsent() =>
        (jsonDecode(settings.lessonProgress!) as Map)['unsent'] as List;

    test('an answer is sent, then no longer kept', () async {
      await repository.saveAttempt(_attempt);
      await repository.sendSaved();

      expect(remote.lessons, ['les']);
      expect(remote.sent.single, containsPair('questionId', 'q1'));
      expect(remote.sent.single, containsPair('lessonVersion', 3));
      expect(remote.sent.single, containsPair('hinted', true));
      await settle();
      expect(unsent(), isEmpty);
    });

    test(
      'offline it stays, and goes later under the same attempt id',
      () async {
        remote.offline = true;
        await repository.saveAttempt(_attempt);
        await settle();
        expect(remote.sent, isEmpty);
        final kept = (unsent().single! as Map)['request'] as Map;

        remote.offline = false;
        await repository.sendSaved();

        expect(remote.sent.single['attemptId'], kept['attemptId']);
        expect(remote.sent.single['attemptId'], isNotEmpty);
      },
    );

    test('answers go in order and survive a new start', () async {
      remote.offline = true;
      await repository.saveAttempt(_attempt);
      await repository.saveAttempt(
        const ExerciseAttempt(
          lessonId: 'les',
          lessonVersion: 3,
          questionId: 'q2',
          draft: ChoiceDraft('o1'),
          hinted: false,
        ),
      );
      await settle();

      remote.offline = false;
      await LessonRepositoryImpl(remote, settings: settings).sendSaved();

      expect(remote.sent.map((a) => a['questionId']), ['q1', 'q2']);
    });

    test('sending twice at once sends each answer once', () async {
      remote.offline = true;
      await repository.saveAttempt(_attempt);
      await settle();
      remote.offline = false;

      await Future.wait([repository.sendSaved(), repository.sendSaved()]);

      expect(remote.sent, hasLength(1));
    });

    test('a lesson keeps its place and hints, each on its own', () async {
      expect(repository.progress('les'), const ExerciseProgress());

      await repository.saveProgress(
        'les',
        const ExerciseProgress(done: {'q1'}, hinted: {'q2'}),
      );

      expect(
        LessonRepositoryImpl(remote, settings: settings).progress('les'),
        const ExerciseProgress(done: {'q1'}, hinted: {'q2'}),
      );
      expect(repository.progress('other'), const ExerciseProgress());
    });

    test('clearing a lesson leaves its unsent answers', () async {
      remote.offline = true;
      await repository.saveAttempt(_attempt);
      await repository.saveProgress(
        'les',
        const ExerciseProgress(done: {'q1'}),
      );
      await settle();

      await repository.clearProgress('les');
      expect(repository.progress('les'), const ExerciseProgress());

      remote.offline = false;
      await repository.sendSaved();
      expect(remote.sent, hasLength(1));
    });

    test('an unreadable store starts empty', () async {
      await settings.setLessonProgress('{not json');

      expect(repository.progress('les'), const ExerciseProgress());
      await repository.saveAttempt(_attempt);
      await settle();
      expect(remote.sent, hasLength(1));
    });

    test('leaving the account forgets all of it', () async {
      remote.offline = true;
      await repository.saveAttempt(_attempt);

      await settings.clearAccountData();

      expect(settings.lessonProgress, isNull);
    });

    test('a guest who becomes a member keeps what was not sent', () async {
      remote.offline = true;
      await repository.saveAttempt(_attempt);
      await repository.saveProgress(
        'les',
        const ExerciseProgress(done: {'q1'}),
      );
      await settle();

      await _session(settings).upgrade(_memberTokens);

      expect(repository.progress('les').done, {'q1'});
      remote.offline = false;
      await repository.sendSaved();
      expect(remote.sent, hasLength(1));
    });

    test('another account starts clean', () async {
      remote.offline = true;
      await repository.saveAttempt(_attempt);
      await settle();

      await _session(settings).signIn(_memberTokens);

      expect(settings.lessonProgress, isNull);
    });

    test('a lesson comes in this phone\'s order, steady', () async {
      final one = await repository.getLesson('les');
      final two = await repository.getLesson('les');

      expect((one as Ok<Lesson>).value, (two as Ok<Lesson>).value);
    });

    group('offline', () {
      Future<Lesson> open(String id) async =>
          ((await repository.getLesson(id)) as Ok<Lesson>).value;

      test('a lesson opened before opens again', () async {
        final online = await open('les');

        remote.offline = true;

        expect(await open('les'), online);
      });

      test('it survives a new start', () async {
        final online = await open('les');
        remote.offline = true;

        final again = LessonRepositoryImpl(remote, settings: settings);

        expect(((await again.getLesson('les')) as Ok<Lesson>).value, online);
      });

      test('a lesson never opened is a network failure', () async {
        remote.offline = true;

        expect(
          await repository.getLesson('les'),
          isA<Err<Lesson>>().having(
            (e) => e.failure,
            'failure',
            isA<NetworkFailure>(),
          ),
        );
      });

      test('online, a lesson not started takes the newer version', () async {
        await open('les');
        remote.lesson = {...sampleLessonJson(), 'version': 2};

        expect((await open('les')).version, 2);
      });

      test('a lesson in progress carries on with its version', () async {
        await open('les');
        await repository.saveProgress(
          'les',
          const ExerciseProgress(done: {'q1'}),
        );
        remote.lesson = {...sampleLessonJson(), 'version': 2};

        expect((await open('les')).version, 1);
      });

      test('a server failure is not treated as offline', () async {
        await open('les');
        remote.failWith = const ApiException(statusCode: 404);

        expect(await repository.getLesson('les'), isA<Err<Lesson>>());
      });

      test('an unreadable cache is no cache', () async {
        await settings.setLessonCache('{not json');
        remote.offline = true;

        expect(await repository.getLesson('les'), isA<Err<Lesson>>());
      });

      test(
        'only the last few are kept, and none in progress is lost',
        () async {
          await open('first');
          await repository.saveProgress(
            'first',
            const ExerciseProgress(done: {'q1'}),
          );
          for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) {
            await open(id);
          }

          final kept = (jsonDecode(settings.lessonCache!) as Map).keys;
          expect(kept, containsAll(['first', 'f', 'e']));
          expect(kept, isNot(contains('a')));
          expect(kept, hasLength(5));
        },
      );

      test('leaving the account forgets the lessons', () async {
        await open('les');

        await settings.clearAccountData();

        expect(settings.lessonCache, isNull);
      });
    });

    group('an answer the server refuses', () {
      for (final status in [400, 404, 409, 410, 422]) {
        test('$status is dropped, and the rest go on', () async {
          remote.offline = true;
          await repository.saveAttempt(_attempt);
          await repository.saveAttempt(
            const ExerciseAttempt(
              lessonId: 'les',
              lessonVersion: 3,
              questionId: 'q2',
              draft: ChoiceDraft('o1'),
              hinted: false,
            ),
          );
          await settle();
          remote
            ..offline = false
            ..refuseOnce = ApiException(statusCode: status);

          await repository.sendSaved();

          expect(remote.sent.map((a) => a['questionId']), ['q2']);
          expect(unsent(), isEmpty);
        });
      }

      test('a server error stays, and goes later', () async {
        remote.refuseOnce = const ApiException(statusCode: 500);
        await repository.saveAttempt(_attempt);
        await settle();
        expect(remote.sent, isEmpty);
        expect(unsent(), hasLength(1));

        await repository.sendSaved();
        expect(remote.sent, hasLength(1));
      });
    });

    test('a failed fetch is a failure, not a throw', () async {
      remote.offline = true;

      expect(await repository.getLesson('les'), isA<Err<Lesson>>());
    });
  });
}
