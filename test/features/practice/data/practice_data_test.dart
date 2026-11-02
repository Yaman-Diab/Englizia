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
import 'package:englizia/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:englizia/features/practice/data/models/word_bank_model.dart';
import 'package:englizia/features/practice/data/repositories/practice_repository_impl.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/services/review_schedule.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_http_adapter.dart';

const _fixture = 'test/fixtures/api/word_bank_ok.json';

Map<String, Object?> _body() =>
    asJsonMap(jsonDecode(File(_fixture).readAsStringSync()));

WordBank _bank() =>
    WordBankModel(asJsonMap(ApiClient.unwrap(_body()))).toEntity();

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

/// The server: what it holds, what it was sent, and whether it can be reached.
class _Remote implements PracticeRemoteDataSource {
  bool offline = false;
  int? refuses;
  final reviews = <Map<String, Object?>>[];
  final removed = <String>[];

  void _reach() {
    if (offline) throw const NetworkException('connectionError');
    if (refuses case final status?) {
      throw ApiException(statusCode: status);
    }
  }

  @override
  Future<WordBankModel> getBank() async {
    if (offline) throw const NetworkException('connectionError');
    return WordBankModel(asJsonMap(ApiClient.unwrap(_body())));
  }

  @override
  Future<void> sendReview(Map<String, Object?> request) async {
    _reach();
    reviews.add(request);
  }

  @override
  Future<void> removeWord(String wordId) async {
    _reach();
    removed.add(wordId);
  }
}

void main() {
  group('the model', () {
    test('the example parses, with its kinds, marks, sources and moments', () {
      final bank = _bank();

      expect(bank.words, hasLength(12));
      expect(bank.sessionSize, 12);
      expect(bank.conceptsDue, 3);
      expect(bank.savedSentences, 9);
      final pickOut = bank.words.firstWhere((w) => w.word == 'pick out');
      expect(pickOut.kind, WordKind.phrasalVerb);
      expect(pickOut.highlighted, {1, 2});
      expect(pickOut.lessonTitle, 'في السوق');
      expect(pickOut.moment?.start, const Duration(milliseconds: 30300));
      expect(pickOut.box, 2);
    });

    test('a word that can\'t be read is left out, and the rest stay', () {
      final json = asJsonMap(ApiClient.unwrap(_body()));
      final words = [...json.readList('words')!];
      words[0] = {...asJsonMap(words[0])}..remove('ar');
      words[1] = {...asJsonMap(words[1]), 'kind': 'interjection', 'box': 9};

      final bank = WordBankModel({...json, 'words': words}).toEntity();

      expect(bank.words, hasLength(11));
      expect(bank.words.first.kind, isNull);
      expect(bank.words.first.box, 5);
    });

    test('with the mistakes\' bank off, there is no concepts row', () {
      final json = {...asJsonMap(ApiClient.unwrap(_body()))}
        ..remove('conceptsDue');

      expect(WordBankModel(json).toEntity().conceptsDue, isNull);
    });

    test('kept on the phone, it reads back the same', () {
      final bank = _bank();

      expect(WordBankModel(WordBankModel.fromEntity(bank)).toEntity(), bank);
    });
  });

  group('the schedule', () {
    final now = DateTime(2026, 11, 2, 15);
    BankWord at(int box, DateTime due) =>
        _bank().words.first.copyWith(box: box, dueAt: due);

    test('«عرفتها» moves a box on, and the last comes back in 30 days', () {
      expect(
        answered(at(2, now), known: true, now: now).dueAt,
        DateTime(2026, 11, 9),
      );
      final last = answered(at(5, now), known: true, now: now);
      expect(last.box, 5);
      expect(last.dueAt, DateTime(2026, 12, 2));
    });

    test('«لم أعرفها» goes back to the first box, for tomorrow', () {
      final again = answered(at(4, now), known: false, now: now);
      expect(again.box, 1);
      expect(again.dueAt, DateTime(2026, 11, 3));
    });

    test('a review takes what is due, the longest waiting first', () {
      final bank = WordBank(
        sessionSize: 2,
        words: [
          at(1, DateTime(2026, 11, 2)),
          at(1, DateTime(2026, 10, 30)),
          at(1, DateTime(2026, 11, 1)),
          at(1, DateTime(2026, 11, 5)),
        ],
      );

      expect(sessionWords(bank, now).map((w) => w.dueAt), [
        DateTime(2026, 10, 30),
        DateTime(2026, 11, 1),
      ]);
    });

    test('with nothing due, those coming soonest', () {
      final bank = WordBank(
        words: [at(1, DateTime(2026, 11, 9)), at(1, DateTime(2026, 11, 4))],
      );

      expect(sessionWords(bank, now).first.dueAt, DateTime(2026, 11, 4));
    });

    test('boxes count their words, and the first two are still learning', () {
      final bank = WordBank(words: [at(1, now), at(2, now), at(5, now)]);

      expect(boxCounts(bank), [1, 1, 0, 0, 1]);
      expect(isLearning(at(2, now)), isTrue);
      expect(isLearning(at(3, now)), isFalse);
    });
  });

  group('the data source', () {
    test('GET, POST and DELETE where the contract says', () async {
      final adapter = FakeHttpAdapter(
        (options) => FakeResponse(
          200,
          body: options.method == 'GET' ? _body() : {'statusCode': 200},
        ),
      );
      final remote = PracticeRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      );

      final bank = (await remote.getBank()).toEntity();
      await remote.sendReview({'reviewId': 'r1'});
      await remote.removeWord('bw_barn');

      expect(bank.words, hasLength(12));
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /api/v1/app/word-bank',
        'POST /api/v1/app/word-bank/reviews',
        'DELETE /api/v1/app/word-bank/words/bw_barn',
      ]);
    });

    test('mock mode moves the example\'s days to today', () async {
      final today = DateTime(2026, 12, 1, 9);
      final bank = (await PracticeFakeDataSource(
        _DiskBundle(),
        latency: Duration.zero,
        now: () => today,
      ).getBank()).toEntity();

      expect(bank.words.where((w) => isDue(w, today)), hasLength(9));
    });
  });

  group('the repository', () {
    late _Remote remote;
    late SettingsStorageService settings;
    final now = DateTime(2026, 11, 2, 15);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsStorageService(await SharedPreferences.getInstance());
      remote = _Remote();
    });

    PracticeRepositoryImpl repository() =>
        PracticeRepositoryImpl(remote, settings, now: () => now);

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('the server\'s bank is kept, and read offline', () async {
      final subject = repository();
      expect(await subject.getBank(), isA<Ok<WordBank>>());

      remote.offline = true;
      final offline = await repository().getBank();

      expect((offline as Ok<WordBank>).value.words, hasLength(12));
    });

    test('offline with nothing kept, it says so', () async {
      remote.offline = true;

      final result = await repository().getBank();

      expect((result as Err<WordBank>).failure, isA<NetworkFailure>());
    });

    test('an answer moves the word at once and goes with its own id', () async {
      final subject = repository();
      await subject.getBank();
      final word = subject.keptBank!.words.first;

      final moved = await subject.answer(word, known: true);
      await settle();

      expect(moved.box, word.box + 1);
      expect(subject.keptBank!.words.first.box, word.box + 1);
      final sent = remote.reviews.single;
      expect(sent['wordId'], word.id);
      expect(sent['known'], isTrue);
      expect(sent['reviewId'], isNotEmpty);
    });

    test('offline, answers wait in order and the bank keeps them', () async {
      final subject = repository();
      await subject.getBank();
      final words = subject.keptBank!.words;
      remote.offline = true;

      await subject.answer(words[0], known: false);
      await subject.answer(words[1], known: true);
      await subject.remove(words[2]);
      await settle();
      expect(remote.reviews, isEmpty);

      // The server hasn't heard yet, so what is waiting stays on top.
      final shown = await subject.getBank();
      final kept = (shown as Ok<WordBank>).value.words;
      expect(kept.firstWhere((w) => w.id == words[0].id).box, 1);
      expect(kept.any((w) => w.id == words[2].id), isFalse);

      remote.offline = false;
      await subject.sendPending();
      await settle();
      expect(remote.reviews.map((r) => r['wordId']), [
        words[0].id,
        words[1].id,
      ]);
      expect(remote.removed, [words[2].id]);
    });

    test('one refused for good is dropped, and the rest go', () async {
      final subject = repository();
      await subject.getBank();
      final words = subject.keptBank!.words;
      remote.refuses = 404;
      await subject.remove(words[0]);
      await settle();
      expect(settings.wordBankOutbox, '[]');

      remote.refuses = 500;
      await subject.answer(words[1], known: true);
      await settle();
      expect(remote.reviews, isEmpty);
      expect(settings.wordBankOutbox, isNot('[]'));
    });

    test('signing out forgets the bank', () async {
      final subject = repository();
      await subject.getBank();

      await settings.clearAccountData();

      expect(subject.keptBank, isNull);
    });
  });
}
