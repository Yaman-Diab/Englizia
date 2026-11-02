import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/concept_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/concept_model.dart';
import 'package:englizia/features/lessons/data/repositories/concept_repository_impl.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/concept_stations.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_http_adapter.dart';

const _fixture = 'test/fixtures/api/concepts_ok.json';

Map<String, Object?> _body() =>
    asJsonMap(jsonDecode(File(_fixture).readAsStringSync()));

Map<String, Object?> _data() => asJsonMap(ApiClient.unwrap(_body()));

/// The server: what it holds, what it was sent, and whether it can be reached.
class _Remote implements ConceptRemoteDataSource {
  bool offline = false;
  int? refuses;
  final answers = <Map<String, Object?>>[];
  final reports = <Map<String, Object?>>[];

  void _reach() {
    if (offline) throw const NetworkException('connectionError');
    if (refuses case final status?) throw ApiException(statusCode: status);
  }

  @override
  Future<ConceptBankModel> getBank() async {
    if (offline) throw const NetworkException('connectionError');
    return ConceptBankModel(_data());
  }

  @override
  Future<void> sendAnswer(Map<String, Object?> request) async {
    _reach();
    answers.add(request);
  }

  @override
  Future<void> sendReport(Map<String, Object?> request) async {
    _reach();
    reports.add(request);
  }
}

void main() {
  group('the model', () {
    test('the example parses, each with a question of another template', () {
      final bank = ConceptBankModel(_data()).toEntity();

      expect(bank.due, hasLength(3));
      expect(bank.later, hasLength(2));
      expect(bank.mastered, hasLength(7));
      final first = bank.due.first;
      expect(first.stations, 0);
      expect(first.repeats, 3);
      expect(first.wrongAnswer, 'She go to school every day.');
      expect(first.example.where((part) => part.strong).single.text, 'goes');
      expect(first.question, isA<FillTypedExercise>());
      expect(bank.due[1].question, isA<MultipleChoiceExercise>());
      expect(bank.due[2].question, isA<FillChoicesExercise>());
      expect(bank.later.first.dueAt, isNotNull);
    });

    test('one that can\'t be read is left out, and the rest stay', () {
      final json = _data();
      final due = [...json.readList('due')!];
      due[0] = {...asJsonMap(due[0])}..remove('why');
      due[1] = {...asJsonMap(due[1]), 'stations': 9};

      final bank = ConceptBankModel({...json, 'due': due}).toEntity();

      expect(bank.due, hasLength(2));
      expect(bank.due.first.stations, 4);
    });

    test('an answer goes with its own id', () {
      final json = conceptAnswerToJson(
        answerId: 'a1',
        conceptId: 'c1',
        questionId: 'q1',
        correct: false,
        at: DateTime.utc(2026, 11, 2, 9),
      );

      expect(json, {
        'answerId': 'a1',
        'conceptId': 'c1',
        'questionId': 'q1',
        'correct': false,
        'answeredAt': '2026-11-02T09:00:00.000Z',
      });
    });
  });

  group('the stations', () {
    test('a right answer passes a station; the fifth masters it', () {
      final step = outcomeOf(1, correct: true);
      expect(step.kind, OutcomeKind.step);
      expect(step.to, 2);
      expect(step.wait, 7);

      final mastered = outcomeOf(4, correct: true);
      expect(mastered.kind, OutcomeKind.mastered);
      expect(mastered.wait, isNull);
    });

    test('wrong at the first two starts over tomorrow', () {
      for (final passed in [0, 1]) {
        final again = outcomeOf(passed, correct: false);
        expect(again.to, 0);
        expect(again.startsOver, isTrue);
        expect(again.wait, 1);
      }
    });

    test('wrong later goes back two stations, and keeps the rest', () {
      final again = outcomeOf(3, correct: false);

      expect(again.to, 1);
      expect(again.startsOver, isFalse);
      expect(again.wait, 3);
    });
  });

  group('the data source', () {
    test('GET and POST where the contract says', () async {
      final adapter = FakeHttpAdapter(
        (options) => FakeResponse(
          200,
          body: options.method == 'GET' ? _body() : {'statusCode': 200},
        ),
      );
      final remote = ConceptRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      );

      final bank = (await remote.getBank()).toEntity();
      await remote.sendAnswer({'answerId': 'a1'});
      await remote.sendReport({'reportId': 'r1'});

      expect(bank.due, hasLength(3));
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /api/v1/app/concepts',
        'POST /api/v1/app/concepts/answers',
        'POST /api/v1/app/concepts/reports',
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

    ConceptRepositoryImpl repository() => ConceptRepositoryImpl(
      remote,
      settings,
      now: () => DateTime.utc(2026, 11, 2, 9),
    );

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test(
      'the concepts and their questions are kept, and read offline',
      () async {
        await repository().getBank();
        remote.offline = true;

        final result = await repository().getBank();

        final bank = (result as Ok<ConceptBank>).value;
        expect(bank.due, hasLength(3));
        expect(bank.due.first.question, isNotNull);
      },
    );

    test('offline with nothing kept, it says so', () async {
      remote.offline = true;

      final result = await repository().getBank();

      expect((result as Err<ConceptBank>).failure, isA<NetworkFailure>());
    });

    test(
      'an answered concept leaves today\'s list until the server has it',
      () async {
        final subject = repository();
        await subject.getBank();
        final first = subject.keptBank!.due.first;
        remote.offline = true;

        final outcome = await subject.answer(first, correct: true);
        await settle();

        expect(outcome.kind, OutcomeKind.step);
        expect(remote.answers, isEmpty);
        expect(
          subject.keptBank!.due.map((c) => c.id),
          isNot(contains(first.id)),
        );

        remote.offline = false;
        await subject.sendPending();
        await settle();
        final sent = remote.answers.single;
        expect(sent['conceptId'], first.id);
        expect(sent['questionId'], first.question!.id);
        expect(sent['correct'], isTrue);
      },
    );

    test('a report goes with the concept and its question', () async {
      final subject = repository();
      await subject.getBank();
      final first = subject.keptBank!.due.first;

      await subject.report(first, ProblemReason.question);
      await settle();

      expect(remote.reports.single['conceptId'], first.id);
      expect(remote.reports.single['reason'], 'question');
    });

    test('one refused for good is dropped', () async {
      final subject = repository();
      await subject.getBank();
      remote.refuses = 410;

      await subject.answer(subject.keptBank!.due.first, correct: false);
      await settle();

      expect(settings.conceptsOutbox, '[]');
    });

    test('signing out forgets them', () async {
      final subject = repository();
      await subject.getBank();

      await settings.clearAccountData();

      expect(subject.keptBank, isNull);
    });
  });
}
