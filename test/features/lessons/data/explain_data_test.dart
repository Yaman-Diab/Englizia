import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/data/datasources/explain_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/explanation_model.dart';
import 'package:englizia/features/lessons/data/repositories/explain_repository_impl.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/explanation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';

const _fixture = 'test/fixtures/api/explanation_ok.json';

Map<String, Object?> _body() =>
    asJsonMap(jsonDecode(File(_fixture).readAsStringSync()));

Map<String, Object?> _data() => asJsonMap(ApiClient.unwrap(_body()));

const _request = ExplainRequest(
  questionId: 'Q1',
  lessonId: 'les_1',
  draft: ChoiceDraft('o1'),
  lessonExplanation: 'مع he/she/it نضيف s للفعل.',
);

/// The server: how many explanations are left, and whether it can be reached.
class _Remote implements ExplainRemoteDataSource {
  bool offline = false;
  var left = 2;
  final asked = <Map<String, Object?>>[];
  final rated = <(String, Map<String, Object?>)>[];

  @override
  Future<ExplainModel> explain(Map<String, Object?> request) async {
    asked.add(request);
    if (offline) throw const NetworkException('connectionError');
    if (left <= 0) return const ExplainModel({'status': 'quotaOut'});
    return ExplainModel({..._data(), 'left': --left});
  }

  @override
  Future<void> rate(String explanationId, Map<String, Object?> request) async {
    if (offline) throw const NetworkException('connectionError');
    rated.add((explanationId, request));
  }
}

void main() {
  group('the model', () {
    test('the wrong word, the one put right, why, and an example', () {
      final outcome = ExplainModel(_data()).toEntity() as ExplainReady;
      final explanation = outcome.explanation;

      expect(outcome.left, 4);
      expect(explanation.yours.where((w) => w.marked).map((w) => w.text), [
        'go',
      ]);
      expect(explanation.right.where((w) => w.marked).map((w) => w.text), [
        'goes',
      ]);
      expect(explanation.why, isNotEmpty);
      expect(explanation.example, 'My brother plays football on Fridays.');
      expect(explanation.exampleAudioUrl, isNotNull);
    });

    test('none left today', () {
      expect(
        const ExplainModel({'status': 'quotaOut'}).toEntity(),
        isA<ExplainQuotaOut>(),
      );
    });

    test('the request carries the question and the answer as sent', () {
      expect(explainRequestToJson(_request), {
        'questionId': 'Q1',
        'lessonId': 'les_1',
        'answer': {'optionId': 'o1'},
      });
    });
  });

  group('the data source', () {
    test('POST where the contract says', () async {
      final adapter = FakeHttpAdapter(
        (options) => FakeResponse(
          200,
          body: options.path.endsWith('rating') ? {'statusCode': 200} : _body(),
        ),
      );
      final remote = ExplainRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      );

      await remote.explain({'questionId': 'Q1'});
      await remote.rate('ex_Q1', {'helpful': true});

      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /api/v1/app/explanations',
        'POST /api/v1/app/explanations/ex_Q1/rating',
      ]);
    });
  });

  group('the repository', () {
    late _Remote remote;
    late DateTime now;

    setUp(() {
      remote = _Remote();
      now = DateTime(2026, 11, 2, 10);
    });

    ExplainRepositoryImpl repository() =>
        ExplainRepositoryImpl(remote, now: () => now);

    test('one asked for again comes at once, and counts nothing', () async {
      final subject = repository();

      final first = await subject.explain(_request);
      final again = await subject.explain(_request);

      expect((first as Ok<ExplainOutcome>).value, isA<ExplainReady>());
      final ready = (again as Ok<ExplainOutcome>).value as ExplainReady;
      expect(ready.fresh, isFalse);
      expect(ready.left, 1);
      expect(remote.asked, hasLength(1));
    });

    test(
      'another answer to the same question is another explanation',
      () async {
        final subject = repository();

        await subject.explain(_request);
        await subject.explain(
          const ExplainRequest(questionId: 'Q1', draft: ChoiceDraft('o3')),
        );

        expect(remote.asked, hasLength(2));
      },
    );

    test('none left: the server isn\'t asked again until tomorrow', () async {
      remote.left = 0;
      final subject = repository();

      await subject.explain(_request);
      final later = await subject.explain(
        const ExplainRequest(questionId: 'Q2', draft: ChoiceDraft('o1')),
      );
      expect((later as Ok<ExplainOutcome>).value, isA<ExplainQuotaOut>());
      expect(remote.asked, hasLength(1));

      now = now.add(const Duration(days: 1));
      remote.left = 3;
      final tomorrow = await subject.explain(
        const ExplainRequest(questionId: 'Q2', draft: ChoiceDraft('o1')),
      );
      expect((tomorrow as Ok<ExplainOutcome>).value, isA<ExplainReady>());
    });

    test('a failure is said, and asking again works', () async {
      final subject = repository();
      remote.offline = true;

      final failed = await subject.explain(_request);
      expect((failed as Err<ExplainOutcome>).failure, isA<NetworkFailure>());

      remote.offline = false;
      final again = await subject.explain(_request);
      expect((again as Ok<ExplainOutcome>).value, isA<ExplainReady>());
    });

    test('the thumbs go with the explanation', () async {
      await repository().rate('ex_Q1', helpful: false);

      final (id, request) = remote.rated.single;
      expect(id, 'ex_Q1');
      expect(request, {'helpful': false});
    });
  });
}
