import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/data/models/grammar_model.dart';
import 'package:englizia/features/lessons/data/models/lesson_result_model.dart';
import 'package:englizia/features/lessons/data/models/reader_model.dart';
import 'package:englizia/features/lessons/data/repositories/lesson_repository_impl.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/domain/entities/teacher_question.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';
import 'package:englizia/features/lessons/domain/services/feedback_content.dart';
import 'package:englizia/features/lessons/domain/services/stable_order.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';

class _Remote implements LessonRemoteDataSource {
  final sent = <Map<String, Object?>>[];
  final reviewed = <Map<String, Object?>>[];
  final reports = <Map<String, Object?>>[];
  final completed = <Map<String, Object?>>[];
  final watched = <Map<String, Object?>>[];
  final words = <Map<String, Object?>>[];
  final contentDone = <Map<String, Object?>>[];
  final lessons = <String>[];
  var reviewSays = true;
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
  Future<bool> reviewAnswer(
    String lessonId,
    Map<String, Object?> request,
  ) async {
    if (offline) throw const NetworkException('connectionError');
    reviewed.add(request);
    return reviewSays;
  }

  @override
  Future<void> sendWord(String lessonId, Map<String, Object?> request) async {
    if (offline) throw const NetworkException('connectionError');
    words.add(request);
  }

  @override
  Future<void> sendContentDone(
    String lessonId,
    Map<String, Object?> request,
  ) async {
    if (offline) throw const NetworkException('connectionError');
    contentDone.add(request);
  }

  @override
  Future<void> sendWatch(String lessonId, Map<String, Object?> request) async {
    if (offline) throw const NetworkException('connectionError');
    watched.add(request);
  }

  @override
  Future<LessonResult> completeLesson(
    String lessonId,
    Map<String, Object?> request,
  ) async {
    if (offline) throw const NetworkException('connectionError');
    completed.add(request);
    return const LessonResult(xp: 15);
  }

  @override
  Future<Evaluation> reviewSpoken(
    String lessonId,
    Map<String, Object?> request,
  ) async {
    if (offline) throw const NetworkException('connectionError');
    reviewed.add(request);
    return const SpokenAnswered(note: 'A note.');
  }

  @override
  Future<void> sendReport(String lessonId, Map<String, Object?> request) async {
    if (offline) throw const NetworkException('connectionError');
    reports.add(request);
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
      expect(lesson.exercises[4], isA<FillChoicesExercise>());
      expect(lesson.exercises[5], isA<WordOrderExercise>());
      expect(lesson.exercises[6], isA<MatchingExercise>());
      expect(lesson.exercises[7], isA<MatchingExercise>());
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
        lesson.exercises[3].bookReference,
        const BookReference(page: 34, exercise: 2),
      );
      expect(lesson.exercises.first.bookReference, isNull);
    });

    test('a sentence with blanks has its words, the extra ones too', () {
      final fill = lesson.exercises[4] as FillChoicesExercise;
      expect(fill.segments, ['If it', 'tomorrow, we', 'stay at home.']);
      expect(fill.blanks.map((b) => b.answer), ['rains', 'will']);
      expect(fill.bank.map((c) => c.text).toSet(), {
        'rains',
        'will',
        'rained',
        'would',
        'is',
      });
    });

    test('word order has its cards, shuffled, and its other forms', () {
      final order = lesson.exercises[5] as WordOrderExercise;
      expect(order.meaning, isNotEmpty);
      expect(order.answerWords, hasLength(6));
      expect(order.bank, hasLength(7));
      expect(order.alternatives, hasLength(1));
    });

    test('matching checks itself, in two shuffled columns', () {
      final text = lesson.exercises[6] as MatchingExercise;
      final pictures = lesson.exercises[7] as MatchingExercise;
      expect(text.checksItself, isTrue);
      expect(text.pictures, isFalse);
      expect(text.pairs.first.meaning, isNotEmpty);
      expect(text.meaningsShown.toSet(), text.pairs.toSet());
      expect(text.wordsShown.toSet(), text.pairs.toSet());
      expect(pictures.pictures, isTrue);
      expect(pictures.pairs.first.image, endsWith('.svg'));
      expect(pictures.pairs.first.alt, isNotEmpty);
    });

    test('carries what the feedback needs', () {
      final first = lesson.exercises.first;
      expect(first.explanation, isNotEmpty);
      expect(first.answerClipUrl, contains('she_goes'));
      expect(lesson.exercises[2].answerClipUrl, contains('market'));
      expect(
        (lesson.exercises[2] as ListenChooseExercise).transcript,
        isNotEmpty,
      );
      expect(lesson.xpPerAnswer, 10);
      expect(lesson.explainEnabled, isTrue);
      final order = lesson.exercises[5] as WordOrderExercise;
      expect(order.reviewable, hasLength(1));
      expect(order.answerClipUrl, contains('sara'));
    });

    test('with no XP or AI from the server, there are none', () {
      final plain = _parse([_question({})]);
      expect(plain.xpPerAnswer, isNull);
      expect(plain.explainEnabled, isFalse);
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

    Map<String, Object?> fill(Map<String, Object?> changes) => {
      'id': 'f',
      'template': 'fillChoices',
      'instructionAr': 'a',
      'prompt': {'en': 'One ___ two ___.'},
      'blanks': [
        {'answer': 'x'},
        {'answer': 'y'},
      ],
      ...changes,
    };

    test('a sentence to repeat needs the panel\'s share', () {
      final question = {
        'id': 'r',
        'template': 'repeatSentence',
        'instructionAr': 'a',
        'source': {'text': 'Hi there', 'audio': 'u'},
      };
      final without = LessonModel({
        'id': 'les',
        'version': 1,
        'exercises': [
          question,
          _question({'id': 'good'}),
        ],
      }).toEntity('s');
      expect(without.exercises.single.id, 'good');

      final with_ = LessonModel({
        'id': 'les',
        'version': 1,
        'speechPassPercent': 60,
        'exercises': [question],
      }).toEntity('s');
      expect(
        (with_.exercises.single as RepeatSentenceExercise).passPercent,
        60,
      );
    });

    test(
      'tolerance needs both the question\'s switch and the panel\'s length',
      () {
        Map<String, Object?> lesson(bool tolerant, int? length) => {
          'id': 'les',
          'version': 1,
          'typoMinLetters': ?length,
          'exercises': [
            {
              'id': 'w',
              'template': 'listenWrite',
              'instructionAr': 'a',
              'prompt': {'audio': 'u'},
              'accepted': ['Hello'],
              'typoTolerance': tolerant,
            },
          ],
        };
        int? parsed(bool tolerant, int? length) =>
            (LessonModel(
                      lesson(tolerant, length),
                    ).toEntity('s').exercises.single
                    as ListenWriteExercise)
                .typoMinLetters;

        expect(parsed(true, 5), 5);
        expect(parsed(false, 5), isNull);
        expect(parsed(true, null), isNull);
      },
    );

    test('attempts of the produced answers', () {
      Object? answer(ExerciseDraft draft) => attemptToJson(
        ExerciseAttempt(
          lessonId: 'les',
          lessonVersion: 1,
          questionId: 'q',
          draft: draft,
          hinted: false,
        ),
        'a',
      )['answer'];

      expect(answer(const TextDraft('goes')), {'text': 'goes'});
      expect(answer(const SpeechDraft([true, false, true])), {
        'heardWords': 2,
        'totalWords': 3,
      });
    });

    test('blanks must fit the sentence', () {
      final parsed = _parse([
        fill({
          'blanks': [
            {'answer': 'x'},
          ],
        }),
        fill({'id': 'good'}),
      ]);
      expect(parsed.exercises.single.id, 'good');
    });

    test('word order splits by word when it has no cards', () {
      final parsed = _parse([
        {
          'id': 'o',
          'template': 'wordOrder',
          'instructionAr': 'a',
          'meaningAr': 'b',
          'answer': 'He runs fast',
        },
      ]);
      final order = parsed.exercises.single as WordOrderExercise;
      expect(order.answerWords, ['He', 'runs', 'fast']);
    });

    test('matching needs its words different', () {
      final parsed = _parse([
        {
          'id': 'm',
          'template': 'matching',
          'instructionAr': 'a',
          'pairs': [
            {'left': 'x', 'right': '1'},
            {'left': 'x', 'right': '2'},
          ],
        },
        _question({'id': 'good'}),
      ]);
      expect(parsed.exercises.single.id, 'good');
    });

    test('attempts of the new templates say their words', () {
      const one = WordChip(id: 'c0', text: 'rains');
      const attempt = ExerciseAttempt(
        lessonId: 'les',
        lessonVersion: 3,
        questionId: 'q',
        draft: SlotsDraft([one, null]),
        hinted: false,
      );
      expect(attemptToJson(attempt, 'a')['answer'], {
        'words': ['rains', null],
      });
      expect(
        attemptToJson(
          const ExerciseAttempt(
            lessonId: 'les',
            lessonVersion: 3,
            questionId: 'q',
            draft: SequenceDraft([one], needed: 1),
            hinted: false,
          ),
          'a',
        )['answer'],
        {
          'words': ['rains'],
        },
      );
      expect(
        attemptToJson(
          const ExerciseAttempt(
            lessonId: 'les',
            lessonVersion: 3,
            questionId: 'q',
            draft: PairsDraft(total: 2, mistakes: {'x'}),
            hinted: false,
          ),
          'a',
        )['answer'],
        {
          'mistakes': ['x'],
        },
      );
    });

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

  group('marking what is typed', () {
    final write = sampleExercises().whereType<ListenWriteExercise>().first;
    final fill = sampleExercises().whereType<FillTypedExercise>().first;

    TextEvaluation mark(TypedExercise exercise, String text) =>
        evaluate(exercise, TextDraft(text)) as TextEvaluation;

    test('case, punctuation and spaces do not matter', () {
      expect(
        mark(write, '  WE usually eat dinner, at seven! ').correct,
        isTrue,
      );
    });

    test('an accepted form says which', () {
      expect(mark(write, 'we usually eat dinner at 7').acceptedIndex, 1);
    });

    test('one letter out in a long word: right, and which word', () {
      final result = mark(write, 'We usually eat diner at seven');
      expect(result.correct, isTrue);
      expect(result.fixedWord, 3);
    });

    test('one letter out in a short word is wrong', () {
      expect(mark(write, 'We usually eet dinner at seven').correct, isFalse);
    });

    test('two letters out is wrong', () {
      expect(mark(write, 'We usually eat dinnnner at seven').correct, isFalse);
    });

    test('with tolerance off, a letter out is wrong', () {
      expect(mark(fill, 'gose').correct, isFalse);
      expect(mark(fill, 'GOES').correct, isTrue);
    });

    test('with no length from the panel, none is tolerated', () {
      const strict = ListenWriteExercise(
        id: 'q',
        instruction: 'a',
        accepted: ['dinner'],
        audioUrl: 'u',
      );
      expect(mark(strict, 'diner').correct, isFalse);
    });

    test('a right answer corrected shows the word marked', () {
      final result = mark(write, 'We usually eat diner at seven');
      final parts = spellingParts(write, result)!;
      expect(parts.where((p) => p.underlined).single.text.trim(), 'dinner');
    });

    test('another accepted form offers the first', () {
      final result = mark(write, 'we usually eat dinner at 7');
      expect(otherRightForm(write, null, result), write.accepted.first);
      expect(
        otherRightForm(write, null, mark(write, write.accepted.first)),
        isNull,
      );
    });
  });

  group('what was heard', () {
    final words = ['Sara', 'feeds', 'the', 'chickens', 'before', 'school.'];

    test('each word heard, whatever its case or punctuation', () {
      expect(
        heardWords(words, 'sara feeds the chickens before school'),
        everyElement(isTrue),
      );
    });

    test('a missed word is marked', () {
      expect(heardWords(words, 'Sara feeds the chickens school'), [
        true,
        true,
        true,
        true,
        false,
        true,
      ]);
    });

    test('a word counts as often as it was said', () {
      expect(heardWords(['the', 'cat', 'the'], 'the cat'), [true, true, false]);
    });

    test('the panel sets the share', () {
      const repeat = RepeatSentenceExercise(
        id: 'q',
        instruction: 'a',
        sentence: 'a b c d e f',
        audioUrl: 'u',
        passPercent: 70,
      );
      SpeechEvaluation mark(List<bool> heard) =>
          evaluate(repeat, SpeechDraft(heard)) as SpeechEvaluation;

      expect(mark([true, true, true, true, true, false]).correct, isTrue);
      expect(mark([true, true, true, true, false, false]).correct, isFalse);
    });
  });

  group('what is placed', () {
    final order = sampleExercises().whereType<SentenceOrderExercise>().first;
    final spelling = sampleExercises().whereType<SpellingExercise>().first;

    test('sentences are right in their own place', () {
      final chips = [
        for (final sentence in order.sentences)
          order.bank.firstWhere((c) => c.text == sentence),
      ];
      expect(evaluate(order, SlotsDraft(chips)).correct, isTrue);
      expect(
        evaluate(order, SlotsDraft(chips.reversed.toList())),
        const SlotsEvaluation([false, false, false, false]),
      );
    });

    test('spelling has the word\'s letters and two extra', () {
      expect(spelling.bank.map((c) => c.text).toSet(), {
        'b',
        'a',
        'r',
        'n',
        'e',
        'm',
      });
    });

    test('the sentences show as lines in the right answer', () {
      expect(
        correctAnswerParts(order).single.text.split('\n'),
        order.sentences,
      );
    });
  });

  group('marking what is built', () {
    final all = sampleExercises();
    final fill = all.whereType<FillChoicesExercise>().first;
    final order = all.whereType<WordOrderExercise>().first;

    WordChip chip(List<WordChip> bank, String text) =>
        bank.firstWhere((c) => c.text == text);

    SequenceDraft sequence(List<String> words) => SequenceDraft([
      for (final word in words) chip(order.bank, word),
    ], needed: order.answerWords.length);

    test('each blank has its own verdict', () {
      final result = evaluate(
        fill,
        SlotsDraft([chip(fill.bank, 'rains'), chip(fill.bank, 'would')]),
      );
      expect(result, const SlotsEvaluation([true, false]));
      expect(result.correct, isFalse);
    });

    test('all blanks right is correct', () {
      expect(
        evaluate(
          fill,
          SlotsDraft([chip(fill.bank, 'rains'), chip(fill.bank, 'will')]),
        ).correct,
        isTrue,
      );
    });

    test('a blank takes its alternatives', () {
      const blank = FillBlank(answer: 'big', alternatives: ['large']);
      expect(blank.accepts('large'), isTrue);
      expect(blank.accepts('tall'), isFalse);
    });

    test('the right order is correct, whatever its punctuation', () {
      expect(
        evaluate(
          order,
          sequence(['Sara', 'feeds', 'the', 'chickens', 'before', 'school']),
        ).correct,
        isTrue,
      );
    });

    test('another accepted order is correct, all its words too', () {
      final result = evaluate(
        order,
        sequence(['before', 'school', 'Sara', 'feeds', 'the', 'chickens']),
      );
      expect(result.correct, isTrue);
      expect((result as SequenceEvaluation).words, everyElement(isTrue));
    });

    test('a wrong order marks what is out of place', () {
      final result = evaluate(
        order,
        sequence(['Sara', 'feeds', 'chickens', 'the', 'before', 'school']),
      );
      expect(result.correct, isFalse);
      expect((result as SequenceEvaluation).words, [
        true,
        true,
        false,
        false,
        true,
        true,
      ]);
    });

    test('an order the server judges asks for it', () {
      final result = evaluate(
        order,
        sequence(['the', 'chickens', 'Sara', 'feeds', 'before', 'school']),
      );
      expect((result as SequenceEvaluation).needsReview, isTrue);
      expect(result.correct, isFalse);
    });

    test('a plain wrong order does not', () {
      final result = evaluate(
        order,
        sequence(['Sara', 'feeds', 'chickens', 'the', 'before', 'school']),
      );
      expect((result as SequenceEvaluation).needsReview, isFalse);
    });

    test('an extra word is wrong', () {
      final result = evaluate(
        order,
        sequence([
          'Sara',
          'feeds',
          'the',
          'chickens',
          'before',
          'school',
          'eats',
        ]),
      );
      expect(result.correct, isFalse);
      expect((result as SequenceEvaluation).words.last, isFalse);
    });

    test('text is compared with no case, punctuation or extra spaces', () {
      expect(plainWords('  It\u2019s,  HERE! '), "it's here");
    });

    test('a finished matching is correct, and keeps its mistakes', () {
      final matching = all.whereType<MatchingExercise>().first;
      final result = evaluate(
        matching,
        const PairsDraft(total: 5, mistakes: {'cow'}),
      );
      expect(result.correct, isTrue);
      expect((result as PairsEvaluation).mistakes, {'cow'});
    });
  });

  group('the advanced templates', () {
    final lesson = LessonModel(sampleLessonJson()).toEntity('seed');
    T first<T extends Exercise>() => lesson.exercises.whereType<T>().first;

    test('a translation takes any of its forms, and no more', () {
      final exercise = first<TranslationExercise>();

      expect(exercise.arabic, isNotEmpty);
      expect(
        evaluate(exercise, const TextDraft('i take the bus to work every day')),
        const TextEvaluation(correct: true, acceptedIndex: 1),
      );
      expect(
        evaluate(
          exercise,
          const TextDraft('I go to work by bus evrey dayss'),
        ).correct,
        isFalse,
      );
    });

    test('a correction is right with the word and its fix together', () {
      final exercise = first<ErrorCorrectionExercise>();

      expect(exercise.corrections.map((c) => c.text), contains("doesn't"));
      expect(
        evaluate(
          exercise,
          const CorrectionDraft(tokenId: 't2', replacement: "doesn't"),
        ).correct,
        isTrue,
      );
      expect(
        evaluate(
          exercise,
          const CorrectionDraft(tokenId: 't3', replacement: "doesn't"),
        ).correct,
        isFalse,
      );
      expect(
        evaluate(
          exercise,
          const CorrectionDraft(tokenId: 't2', replacement: 'not'),
        ).correct,
        isFalse,
      );
      expect(const CorrectionDraft(tokenId: 't2').isComplete, isFalse);
    });

    test('a correction whose wrong word is not in the sentence is skipped', () {
      final parsed = _parse(
        [
          _question({
            'template': 'errorCorrection',
            'prompt': {
              'tokens': [
                {'id': 't1', 'text': 'She'},
              ],
            },
            'wrongTokenId': 't9',
            'correction': 'x',
          }),
        ].followedBy([
          _question({'id': 'ok'}),
        ]).toList(),
      );

      expect(parsed.exercises.single.id, 'ok');
    });

    test('a conversation has one line for the learner', () {
      final exercise = first<DialogueExercise>();

      expect(exercise.characterName, 'Lina');
      expect(exercise.lines.where((line) => line.isLearner), hasLength(1));
      final broken = _parse([
        _question({
          'template': 'dialogueCompletion',
          'character': {'name': 'A'},
          'lines': [
            {'speaker': 'character', 'text': 'Hi'},
          ],
        }),
        _question({'id': 'ok'}),
      ]);
      expect(broken.exercises.single.id, 'ok');
    });

    test('a text becomes a step per question, sharing what stays', () {
      final steps = lesson.exercises.whereType<ReadingExercise>().toList();

      expect(steps.map((s) => s.step), [1, 2, 3, 4]);
      expect(steps.every((s) => s.steps == 4), isTrue);
      expect(steps.map((s) => s.stayKey).toSet(), {'q17'});
      expect(steps.map((s) => s.id).toSet(), hasLength(4));
      expect(steps.first.answerClipUrl, isNull);
      expect(steps.first.clipUrl, steps.first.passage.audioUrl);
    });

    test('questions of the AI only where it is on', () {
      Map<String, Object?> withAi(bool? on) => {
        'id': 'les',
        'version': 1,
        'aiReviewEnabled': ?on,
        'exercises': [
          _question({'id': 'ok'}),
          _question({
            'id': 'ai',
            'template': 'speakAnswer',
            'prompt': {'en': 'Why?'},
          }),
        ],
      };

      expect(LessonModel(withAi(true)).toEntity('s').exercises, hasLength(2));
      expect(LessonModel(withAi(false)).toEntity('s').exercises, hasLength(1));
      expect(LessonModel(withAi(null)).toEntity('s').exercises, hasLength(1));
    });

    test('what the AI says is read by its outcome', () {
      expect(
        spokenReviewFromJson({
          'outcome': 'answered',
          'note': 'n',
          'better': 'b',
        }),
        const SpokenAnswered(note: 'n', better: 'b'),
      );
      expect(
        spokenReviewFromJson({'outcome': 'offTopic', 'note': 'n'}),
        const SpokenOffTopic(note: 'n'),
      );
      expect(
        spokenReviewFromJson({'outcome': 'quotaOut'}),
        const ReviewQuotaOut(),
      );
      expect(
        () => spokenReviewFromJson({'outcome': 'new'}),
        throwsFormatException,
      );
    });

    test('a spoken answer is sent as its words, never more', () {
      const attempt = ExerciseAttempt(
        lessonId: 'les',
        lessonVersion: 3,
        questionId: 'q',
        draft: SpokenDraft('I rest', typed: true),
        hinted: false,
      );

      expect(attemptToJson(attempt, 'id')['answer'], {
        'text': 'I rest',
        'typed': true,
      });
    });
  });

  group('an interactive text', () {
    Map<String, Object?> asset(String path) =>
        asJsonMap(ApiClient.unwrap(jsonDecode(File(path).readAsStringSync())));
    final content = readerFromJson(asset(LessonFakeDataSource.textAsset))!;

    test('the mock has its sentences, words, timings and spans', () {
      expect(content.sentences, hasLength(6));
      expect(content.sentences.first.english, startsWith('Sara wakes up'));
      expect(content.spans, hasLength(5));
      expect(content.hasShadowing, isTrue);
      expect(content.duration, const Duration(seconds: 58));
    });

    test('a moment finds its sentence and word, and a gap the next', () {
      final second = content.sentences[1];

      expect(content.placeAt(second.words[2].start), (sentence: 1, word: 2));
      expect(content.placeAt(second.start - const Duration(milliseconds: 1)), (
        sentence: 1,
        word: null,
      ));
      expect(content.placeAt(content.duration).word, isNull);
    });

    test('a word finds its span; one with none has none', () {
      final sentence = content.sentences[4];

      expect(content.spanOf(sentence, sentence.words[1])?.id, 'turnoff');
      expect(content.spanOf(sentence, sentence.words[3])?.id, 'turnoff');
      expect(content.spanOf(sentence, sentence.words[2]), isNull);
    });

    test('other lessons have none, and a broken one costs only itself', () {
      expect(_parse([_question({})]).reader, isNull);

      final broken = LessonModel({
        'id': 'les',
        'version': 1,
        'reader': {
          'audio': {'url': 'a'},
          'sentences': <Object?>[],
        },
        'exercises': [_question({})],
      }).toEntity('s');
      expect(broken.reader, isNull);
      expect(broken.exercises, hasLength(1));
    });

    test('a span of a kind this version does not know is left unmarked', () {
      final parsed = readerFromJson({
        'reader': {
          'audio': {'url': 'a', 'durationMs': 1000},
          'sentences': [
            {
              'id': 's',
              'ar': 'a',
              'words': [
                {'id': 'w', 'text': 'x', 'startMs': 0, 'endMs': 1000},
              ],
            },
          ],
          'spans': [
            {
              'id': 'n',
              'sentenceId': 's',
              'wordIds': ['w'],
              'kind': 'hologram',
              'base': 'x',
              'ar': 'a',
            },
          ],
        },
      });

      expect(parsed?.spans, isEmpty);
    });

    test('settings go to their form and back, and a saved word whole', () {
      const prefs = ReaderPrefs(
        size: ReaderTextSize.large,
        mode: ReaderMode.listening,
        stopEachSentence: true,
      );
      expect(readerPrefsFromJson(readerPrefsToJson(prefs)), prefs);
      expect(
        readerPrefsFromJson({'size': 'x', 'mode': 'y'}),
        const ReaderPrefs(),
      );

      final word = SavedWord(
        lessonId: 'les',
        span: content.spans[3],
        sentence: content.sentences[4],
      );
      final saved = savedWordToJson(word, saved: true);
      expect(saved['base'], 'turn off');
      expect(asJsonMap(saved['sentence'])['en'], contains('turn it off'));
      expect(savedWordToJson(word, saved: false), {
        'spanId': 'turnoff',
        'saved': false,
      });
    });
  });

  group('an interactive video', () {
    Map<String, Object?> asset(String path) =>
        asJsonMap(ApiClient.unwrap(jsonDecode(File(path).readAsStringSync())));
    final json = asset(LessonFakeDataSource.videoAsset);
    final content = readerFromJson(json)!;

    test('the mock has its video, speakers, timings and spans', () {
      final video = content.video!;
      expect(content.audioUrl, isEmpty);
      expect(content.duration, const Duration(seconds: 80));
      expect(video.video.sources, hasLength(4));
      expect(video.requiredPercent, 80);
      expect(video.defaultSpeed, 1);
      expect(content.sentences, hasLength(6));
      expect(content.sentences.first.speaker, 'Omar');
      expect(content.spans, hasLength(4));
      expect(content.hasShadowing, isTrue);
      var last = Duration.zero;
      for (final sentence in content.sentences) {
        for (final word in sentence.words) {
          expect(word.start, greaterThanOrEqualTo(last));
          last = word.end;
        }
      }
      expect(last, lessThan(content.duration));
    });

    test('a span\'s words may have others between them', () {
      final span = content.spans.firstWhere((s) => s.id == 'wrapup');
      expect(span.wordIds, ['s4w3', 's4w5']);
      expect(span.noteExample, isNotEmpty);
    });

    test('the panel\'s speed and the watch so far are read', () {
      final reader = asJsonMap(json['reader']);
      final parsed = readerFromJson({
        'reader': {
          ...reader,
          'defaultSpeed': .75,
          'watch': {
            'videoId': 'vid',
            'positionSeconds': 9,
            'watched': [
              [0, 9],
            ],
          },
        },
      })!;
      expect(parsed.video!.defaultSpeed, .75);
      expect(parsed.video!.savedWatch?.positionSeconds, 9);
    });

    test('with no share to watch, it can\'t be read', () {
      final reader = {...asJsonMap(json['reader'])}
        ..remove('requiredWatchPercent');
      expect(readerFromJson({'reader': reader}), isNull);
    });

    test('a saved word keeps its moment in the video', () {
      final word = SavedWord(
        lessonId: 'les',
        span: content.spans.first,
        sentence: content.sentences.first,
        videoId: 'vid',
      );
      final sentence = asJsonMap(
        savedWordToJson(word, saved: true)['sentence'],
      );
      expect(sentence['videoId'], 'vid');
      expect(sentence['startMs'], content.sentences.first.start.inMilliseconds);
      expect(sentence['endMs'], content.sentences.first.end.inMilliseconds);
    });

    test('a text\'s saved word has no moment', () {
      final word = SavedWord(
        lessonId: 'les',
        span: content.spans.first,
        sentence: content.sentences.first,
      );
      final sentence = asJsonMap(
        savedWordToJson(word, saved: true)['sentence'],
      );
      expect(sentence.containsKey('startMs'), isFalse);
    });

    test('its way of showing is kept with a text\'s', () {
      const prefs = ReaderPrefs(videoMode: ReaderMode.englishOnly);
      expect(readerPrefsFromJson(readerPrefsToJson(prefs)), prefs);
      expect(
        readerPrefsFromJson(const {}).videoMode,
        ReaderMode.currentTranslated,
      );
    });
  });

  group('a grammar lesson', () {
    Map<String, Object?> asset(String path) =>
        asJsonMap(ApiClient.unwrap(jsonDecode(File(path).readAsStringSync())));

    test('the mock has its video, rule and questions on', () {
      final grammar = LessonModel(
        asset(LessonFakeDataSource.grammarAsset),
      ).toEntity('s').grammar!;

      expect(grammar.requiredPercent, 80);
      expect(grammar.questionsEnabled, isTrue);
      expect(grammar.teacherName, isNotEmpty);
      expect(grammar.video?.sources, hasLength(4));
      expect(grammar.video?.captions, isNotEmpty);
      expect(grammar.summary.rows.last.right.last.marked, isTrue);
      expect(grammar.summary.examples.first.english, startsWith('She works'));
    });

    test('with no video it has the book, and no questions', () {
      final grammar = LessonModel(
        asset(LessonFakeDataSource.bookAsset),
      ).toEntity('s').grammar!;

      expect(grammar.video, isNull);
      expect(grammar.bookPage, 34);
      expect(grammar.questionsEnabled, isFalse);
    });

    test('other lessons have none, and a broken one costs only itself', () {
      expect(_parse([_question({})]).grammar, isNull);

      final broken = LessonModel({
        'id': 'les',
        'version': 1,
        'content': {
          'requiredWatchPercent': 80,
          'summary': {'ar': 'a'},
          'video': {'id': 'v', 'durationSeconds': 10, 'sources': <Object?>[]},
        },
        'exercises': [_question({})],
      }).toEntity('s');
      expect(broken.grammar, isNull);
      expect(broken.exercises, hasLength(1));
    });

    test('a required share has to come from the server', () {
      final lesson = LessonModel({
        'id': 'les',
        'version': 1,
        'content': {
          'summary': {'ar': 'a'},
        },
        'exercises': [_question({})],
      }).toEntity('s');

      expect(lesson.grammar, isNull);
    });

    test('a video finds its source, and captions their time', () {
      const video = LessonVideo(
        id: 'v',
        duration: Duration(seconds: 10),
        sources: [
          VideoSource(quality: VideoQuality.auto, url: 'a'),
          VideoSource(quality: VideoQuality.low, url: 'l'),
        ],
        captions: [
          VideoCaption(
            from: Duration(seconds: 1),
            to: Duration(seconds: 2),
            text: 'x',
          ),
        ],
      );

      expect(video.urlFor(VideoQuality.low), 'l');
      expect(video.urlFor(VideoQuality.high), 'a');
      expect(video.captionAt(const Duration(seconds: 1)), 'x');
      expect(video.captionAt(const Duration(seconds: 2)), isNull);
    });

    test('watching goes to and from its form', () {
      const watch = WatchState(
        videoId: 'v',
        positionSeconds: 12,
        ranges: [(0, 5), (8, 12)],
      );

      expect(watchFromJson(watchToJson(watch)), watch);
      expect(watchToJson(watch, lessonVersion: 3)['lessonVersion'], 3);
    });

    test('questions are read with their answers and sent as little', () {
      final question = questionFromJson({
        'questionId': 'q',
        'text': 't',
        'askedAt': '2026-11-01T08:00:00Z',
        'videoSeconds': 134,
        'reply': {'name': 'n', 'role': 'admin', 'text': 'r'},
      });

      expect(question.videoPosition, const Duration(seconds: 134));
      expect(question.reply?.role, ReplierRole.admin);
      expect(questionToJson(question), {
        'questionId': 'q',
        'text': 't',
        'videoSeconds': 134,
      });
    });
  });

  group('the end of a lesson', () {
    test('the package has its place in the unit', () {
      final outline = lessonOutlineFromJson(sampleLessonJson());

      expect(outline.title, isNotEmpty);
      expect(outline.earnsXp, isTrue);
      expect(outline.replay, isFalse);
      expect(outline.unit?.steps, hasLength(6));
      expect(outline.unit?.doneInARow, 3);
      expect(outline.next?.kind, NextKind.lesson);
      expect(outline.next?.lessonKind, LessonKind.grammarVideo);
    });

    test('a package without it still opens', () {
      final lesson = _parse([_question({})]);

      expect(lesson.outline, const LessonOutline());
    });

    test('a broken unit is left out, not the lesson', () {
      final outline = lessonOutlineFromJson({
        'unit': {
          'number': 1,
          'title': 'a',
          'lessons': [
            {'kind': 'vocabulary'},
          ],
        },
      });

      expect(outline.unit, isNull);
    });

    test('a kind this version does not know is still a step', () {
      final outline = lessonOutlineFromJson({
        'unit': {
          'number': 1,
          'title': 'a',
          'lessons': [
            {'id': 'x', 'kind': 'hologram', 'done': true},
          ],
        },
      });

      expect(outline.unit?.steps.single.kind, LessonKind.other);
    });

    test('the mock has every scenario of the design, and all parse', () {
      final results =
          jsonDecode(File(LessonFakeDataSource.resultsAsset).readAsStringSync())
              as List<Object?>;

      final parsed = [
        for (final r in results) lessonResultFromJson(asJsonMap(r)),
      ];
      expect(parsed.where((r) => r.goal?.justMet ?? false), hasLength(1));
      expect(parsed.where((r) => r.replay ?? false), hasLength(1));
      expect(parsed.where((r) => r.xp == null), hasLength(1));
      expect(parsed.where((r) => (r.pending ?? 0) > 0), hasLength(1));
      expect(parsed.map((r) => r.next?.kind).toSet(), {
        NextKind.lesson,
        NextKind.unitReview,
        NextKind.unit,
      });
    });

    test('the goal is just met only by the lesson that reached it', () {
      expect(const DailyGoal(before: 8, now: 10, target: 10).justMet, isTrue);
      expect(const DailyGoal(before: 10, now: 12, target: 10).justMet, isFalse);
      expect(const DailyGoal(before: 5, now: 7, target: 10).met, isFalse);
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
      expect(model.toEntity('s').exercises, hasLength(21));
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

    const spoken = ExerciseAttempt(
      lessonId: 'les',
      lessonVersion: 3,
      questionId: 'q18',
      draft: SpokenDraft('I rest'),
      hinted: false,
    );

    const finished = LessonSummary(
      lessonId: 'les',
      lessonVersion: 3,
      rightFirstTime: 1,
      counted: 1,
      pending: 0,
      seconds: 60,
      outline: LessonOutline(),
    );

    const watch = WatchState(
      videoId: 'v',
      positionSeconds: 5,
      ranges: [(0, 5)],
    );

    test('the reader remembers its settings and its tip', () async {
      expect(repository.readerPrefs, const ReaderPrefs());
      expect(repository.readerTipSeen, isFalse);

      const prefs = ReaderPrefs(size: ReaderTextSize.small);
      await repository.setReaderPrefs(prefs);
      await repository.setReaderTipSeen();

      expect(repository.readerPrefs, prefs);
      expect(repository.readerTipSeen, isTrue);
    });

    test('a star stays on the phone, and goes when it can', () async {
      const word = SavedWord(
        lessonId: 'les',
        span: ReaderSpan(
          id: 'sp',
          sentenceId: 's',
          wordIds: ['w'],
          kind: SpanKind.word,
          base: 'barn',
          arabic: 'a',
        ),
        sentence: ReaderSentence(
          id: 's',
          arabic: 'a',
          words: [
            ReaderWord(
              id: 'w',
              text: 'barn',
              start: Duration.zero,
              end: Duration(seconds: 1),
            ),
          ],
        ),
      );
      remote.offline = true;
      await repository.setWordSaved(word, saved: true);
      await settle();
      expect(repository.savedWords('les'), {'sp'});
      expect(remote.words, isEmpty);

      remote.offline = false;
      await repository.sendSaved();
      await settle();
      expect(remote.words.single['spanId'], 'sp');

      await repository.setWordSaved(word, saved: false);
      await settle();
      expect(repository.savedWords('les'), isEmpty);
      expect(remote.words.last['saved'], isFalse);
    });

    test('finishing the content goes with its version', () async {
      await repository.sendContentDone('les', 3);
      await settle();

      expect(remote.contentDone.single['lessonVersion'], 3);
    });

    test('watching stays on the phone for its video', () async {
      expect(repository.savedWatch('les'), isNull);

      await repository.saveWatch('les', watch);

      expect(repository.savedWatch('les'), watch);
      expect(repository.savedWatch('other'), isNull);
    });

    test('only the latest watching goes, once it can', () async {
      remote.offline = true;
      await repository.sendWatch('les', 3, watch);
      await settle();
      await repository.sendWatch(
        'les',
        3,
        const WatchState(videoId: 'v', positionSeconds: 9, ranges: [(0, 9)]),
      );
      await settle();

      remote.offline = false;
      await repository.sendSaved();
      await settle();

      expect(remote.watched, hasLength(1));
      expect(remote.watched.single['positionSeconds'], 9);
      expect(remote.watched.single['lessonVersion'], 3);
    });

    test(
      'the quality chosen is remembered, and is automatic at first',
      () async {
        expect(repository.videoQuality, VideoQuality.auto);

        await repository.setVideoQuality(VideoQuality.low);

        expect(repository.videoQuality, VideoQuality.low);
      },
    );

    test('completing a lesson sends its answers first', () async {
      await repository.saveAttempt(_attempt);
      await settle();
      remote.sent.clear();
      remote.offline = true;
      await repository.saveAttempt(_attempt);
      await settle();
      remote.offline = false;

      final result = await repository.completeLesson(finished);

      expect(remote.sent, hasLength(1));
      expect(result, const Ok(LessonResult(xp: 15)));
      expect(remote.completed.single['lessonVersion'], 3);
      expect(remote.completed.single['seconds'], 60);
    });

    test('with no connection it waits, and goes with its one id', () async {
      remote.offline = true;
      final first = await repository.completeLesson(finished);
      final again = await repository.completeLesson(finished);
      expect(first, isA<Err<LessonResult>>());
      expect(again, isA<Err<LessonResult>>());

      remote.offline = false;
      await repository.sendSaved();
      await settle();

      expect(remote.completed, hasLength(1), reason: 'kept once');
      final id = remote.completed.single['completionId'];

      final late = await repository.completeLesson(finished);
      expect(late, isA<Ok<LessonResult>>());
      expect(remote.completed.last['completionId'], id);
    });

    test('a spoken answer judged now leaves nothing to send', () async {
      final result = await repository.reviewSpoken(spoken);
      await settle();

      expect(result, isA<Ok<Evaluation>>());
      expect(remote.reviewed.single['answer'], {
        'text': 'I rest',
        'typed': false,
      });
      expect(remote.sent, isEmpty);
    });

    test(
      'a spoken answer the server missed goes later, the same attempt',
      () async {
        remote.offline = true;
        final result = await repository.reviewSpoken(spoken);
        await settle();
        expect(result, isA<Err<Evaluation>>());

        remote.offline = false;
        await repository.sendSaved();

        expect(remote.sent.single['questionId'], 'q18');
        expect(remote.sent.single['attemptId'], isNotEmpty);
      },
    );

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

    group('judging and reporting', () {
      const report = ExerciseReport(
        lessonId: 'les',
        lessonVersion: 3,
        questionId: 'q1',
        reason: ProblemReason.alsoRight,
        draft: ChoiceDraft('o2'),
      );

      test('a review goes with the attempt\'s own id', () async {
        remote.offline = true;
        final id = await repository.saveAttempt(_attempt);
        remote.offline = false;

        final result = await repository.reviewAttempt(_attempt, id);

        expect((result as Ok<bool>).value, isTrue);
        expect(remote.reviewed.single['attemptId'], id);
      });

      test('the server may say it is wrong', () async {
        remote.reviewSays = false;

        final result = await repository.reviewAttempt(_attempt, 'a');

        expect((result as Ok<bool>).value, isFalse);
      });

      test('no connection for a review is a failure', () async {
        remote.offline = true;

        expect(await repository.reviewAttempt(_attempt, 'a'), isA<Err<bool>>());
      });

      test('a report goes with its context', () async {
        await repository.saveReport(report);
        await repository.sendSaved();

        expect(remote.reports.single, containsPair('reason', 'alsoRight'));
        expect(remote.reports.single, containsPair('lessonVersion', 3));
        expect(remote.reports.single, containsPair('questionId', 'q1'));
        expect(remote.reports.single['answer'], {'optionId': 'o2'});
        expect(remote.reports.single['reportId'], isNotEmpty);
        expect(remote.sent, isEmpty);
      });

      test('offline it waits, in order with the answers', () async {
        remote.offline = true;
        await repository.saveAttempt(_attempt);
        await repository.saveReport(report);
        await settle();
        expect(unsent(), hasLength(2));

        remote.offline = false;
        await repository.sendSaved();

        expect(remote.sent, hasLength(1));
        expect(remote.reports, hasLength(1));
        expect(unsent(), isEmpty);
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
