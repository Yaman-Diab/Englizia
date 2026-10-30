import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/data/repositories/lesson_repository_impl.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_lesson_repository.dart';

class _Remote implements LessonRemoteDataSource {
  final sent = <Map<String, Object?>>[];
  final lessons = <String>[];
  var offline = false;

  @override
  Future<List<Exercise>> getExercises(String lessonId) async =>
      offline ? throw const NetworkException('connectionError') : const [];

  @override
  Future<void> sendAnswer(String lessonId, Map<String, Object?> answer) async {
    if (offline) throw const NetworkException('connectionError');
    lessons.add(lessonId);
    sent.add(answer);
  }
}

const _answer = ExerciseAnswer(
  lessonId: 'les',
  questionId: 'q1',
  optionId: 'o2',
  hinted: true,
);

void main() {
  group('the example lesson', () {
    final questions = sampleExercises();

    test('has each template', () {
      expect(questions.map((q) => q.kind), [
        ExerciseKind.multipleChoice,
        ExerciseKind.imageChoice,
        ExerciseKind.listeningChoice,
        ExerciseKind.multipleChoice,
      ]);
    });

    test('carries the sentence, its hint and its key', () {
      final first = questions.first;
      expect(first.before, 'She');
      expect(first.after, 'to school every day.');
      expect(first.hint?.term, 'she');
      expect(first.hint?.text.of('ar'), isNotEmpty);
      expect(first.options.where((o) => o.correct).single.text, 'goes');
    });

    test('names its pictures, and has no hint on them', () {
      final picture = questions[1];
      expect(picture.word, 'barn');
      expect(picture.hint, isNull);
      expect(picture.audioUrl, isNotEmpty);
      expect(picture.options.first.imageUrl, endsWith('.svg'));
      expect(picture.options.first.imageAlt?.of('en'), 'A barn');
    });

    test('says where a question is in the book', () {
      expect(questions.last.bookReference?.of('en'), contains('page 34'));
      expect(questions.first.bookReference, isNull);
    });
  });

  group('parsing', () {
    Map<String, Object?> question(String type) => {
      'id': 'q',
      'type': type,
      'instruction': {'ar': 'a', 'en': 'b'},
      'options': [
        {'id': 'o1', 'text': 'x', 'correct': true},
      ],
    };

    test('a kind this version does not know is left out', () {
      final parsed = exercisesFromJson({
        'questions': [question('wordOrder'), question('multipleChoice')],
      });
      expect(parsed.map((q) => q.kind), [ExerciseKind.multipleChoice]);
    });

    test('a question with no options is a format error', () {
      expect(
        () => exercisesFromJson({
          'questions': [
            {...question('multipleChoice'), 'options': <Object?>[]},
          ],
        }),
        throwsFormatException,
      );
    });

    test('no questions is an empty lesson', () {
      expect(exercisesFromJson({}), isEmpty);
    });
  });

  group('the endpoints', () {
    late FakeHttpAdapter adapter;
    late LessonRemoteDataSourceImpl source;

    setUp(() {
      adapter = FakeHttpAdapter((_) => const FakeResponse(200));
      source = LessonRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      );
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

    test('an answer is sent, then no longer kept', () async {
      await repository.saveAnswer(_answer);
      await repository.sendSaved();

      expect(remote.lessons, ['les']);
      expect(remote.sent.single, containsPair('questionId', 'q1'));
      expect(remote.sent.single, containsPair('optionId', 'o2'));
      expect(remote.sent.single, containsPair('hinted', true));
      expect(remote.sent.single, isNot(contains('lessonId')));
      await settle();
      final saved = jsonDecode(settings.lessonProgress!) as Map;
      expect(saved['unsent'], isEmpty);
    });

    test(
      'offline it stays, and goes later under the same attempt id',
      () async {
        remote.offline = true;
        await repository.saveAnswer(_answer);
        await settle();
        expect(remote.sent, isEmpty);
        final kept =
            ((jsonDecode(settings.lessonProgress!) as Map)['unsent'] as List)
                    .single
                as Map;

        remote.offline = false;
        await repository.sendSaved();

        expect(remote.sent.single['attemptId'], kept['attemptId']);
        expect(remote.sent.single['attemptId'], isNotEmpty);
      },
    );

    test('answers go in order and survive a new start', () async {
      remote.offline = true;
      await repository.saveAnswer(_answer);
      await repository.saveAnswer(
        const ExerciseAnswer(
          lessonId: 'les',
          questionId: 'q2',
          optionId: 'o1',
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
      await repository.saveAnswer(_answer);
      await settle();
      remote.offline = false;

      await Future.wait([repository.sendSaved(), repository.sendSaved()]);

      expect(remote.sent, hasLength(1));
    });

    test('a lesson keeps its place and hints, each on its own', () async {
      expect(repository.progress('les'), const ExerciseProgress());

      await repository.saveProgress(
        'les',
        const ExerciseProgress(position: 2, hinted: {'q1'}),
      );

      expect(
        LessonRepositoryImpl(remote, settings: settings).progress('les'),
        const ExerciseProgress(position: 2, hinted: {'q1'}),
      );
      expect(repository.progress('other'), const ExerciseProgress());
    });

    test('clearing a lesson leaves its unsent answers', () async {
      remote.offline = true;
      await repository.saveAnswer(_answer);
      await repository.saveProgress('les', const ExerciseProgress(position: 2));
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
      await repository.saveAnswer(_answer);
      await settle();
      expect(remote.sent, hasLength(1));
    });

    test('leaving the account forgets all of it', () async {
      remote.offline = true;
      await repository.saveAnswer(_answer);

      await settings.clearAccountData();

      expect(settings.lessonProgress, isNull);
    });

    test('a failed fetch is a failure, not a throw', () async {
      remote.offline = true;

      expect(await repository.getExercises('les'), isA<Err<List<Exercise>>>());
    });
  });
}
