import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/text/plain_words.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/data/models/sync_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

/// The dev server's own answers (`test/fixtures/api`).
Object? _body(String name) =>
    jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync());

Map<String, Object?> _data(String name) =>
    asJsonMap(ApiClient.unwrap(_body(name)));

Map<String, Object?> _lessonJson() => _data('app_lesson_grammar');

/// The answer that is right, as the learner would give it.
ExerciseDraft _rightDraft(Exercise exercise) => switch (exercise) {
  ChoiceExercise(:final answerId) => ChoiceDraft(answerId),
  FillChoicesExercise(:final blanks, :final bank) => SlotsDraft([
    for (final blank in blanks)
      bank.firstWhere((chip) => chip.text == blank.answer),
  ]),
  WordOrderExercise(:final answerWords, :final bank) => SequenceDraft([
    for (final word in answerWords)
      bank.firstWhere((chip) => chip.text == word),
  ], needed: answerWords.length),
  MatchingExercise(:final pairs) => PairsDraft(
    total: pairs.length,
    matched: {for (final pair in pairs) pair.id},
  ),
  _ => throw StateError('No such template on the server'),
};

Map<String, Object?>? _sent(
  Map<String, Object?> lesson,
  String questionId,
  ExerciseDraft draft, {
  bool hinted = false,
}) => syncAttemptToJson(
  ExerciseAttempt(
    lessonId: 'les',
    lessonVersion: 1,
    questionId: questionId,
    draft: draft,
    hinted: hinted,
  ),
  lesson: LessonModel(lesson).own,
  attemptId: 'attempt',
  runId: 'run',
  at: DateTime.utc(2026, 11, 20, 14),
);

/// A lesson of one matching, as the server sends it.
Map<String, Object?> _matching({
  List<int> key = const [2, 0, 1],
  String rightKind = 'text',
}) => {
  'id': 'les',
  'versionId': 'v1',
  'versionNo': 1,
  'type': 'vocabulary',
  'titleAr': 'a',
  'content': null,
  'questions': [
    {
      'versionId': 'm',
      'template': 'matching',
      'instructionAr': 'a',
      'body': {
        'rightKind': rightKind,
        'left': ['one', 'two', 'three'],
        'right': [
          {'text': 'B', 'imageMediaId': 'img'},
          {'text': 'C', 'imageMediaId': 'img'},
          {'text': 'A', 'imageMediaId': 'img'},
        ],
      },
      'answerKey': {'pairs': key},
    },
  ],
  'media': {
    'img': {'kind': 'image', 'url': 'https://example.com/a.webp'},
  },
};

void main() {
  group('the server’s lesson', () {
    late Lesson lesson;

    setUp(() => lesson = LessonModel(_lessonJson()).toEntity('seed'));

    test('opens with its version and its six templates', () {
      expect(lesson.id, '01a1f24f-eec9-7d31-8c4b-624e894c7858');
      expect(lesson.version, 1);
      expect(lesson.outline.title, 'الفعل to be: am وis وare');
      expect(lesson.exercises.map((e) => e.runtimeType), [
        MultipleChoiceExercise,
        ImageChoiceExercise,
        FillChoicesExercise,
        WordOrderExercise,
        MatchingExercise,
        ListenChooseExercise,
      ]);
    });

    test('a question is known by its version, as an answer names it', () {
      final questions = _lessonJson().readList('questions')!;

      expect(lesson.exercises.map((e) => e.id), [
        for (final question in questions) asJsonMap(question)['versionId'],
      ]);
    });

    test('media come as addresses', () {
      final picture = lesson.exercises[1] as ImageChoiceExercise;
      final heard = lesson.exercises[5] as ListenChooseExercise;

      expect(picture.word, 'She is a teacher.');
      expect(picture.options.every((o) => o.image.endsWith('.webp')), isTrue);
      expect(heard.audioUrl, endsWith('.mp3'));
      expect(heard.transcript, 'You are my friend.');
    });

    test('the cards hold the answer and the extra ones', () {
      final fill = lesson.exercises[2] as FillChoicesExercise;
      final order = lesson.exercises[3] as WordOrderExercise;

      expect(fill.segments, ['We', 'friends.']);
      expect(fill.bank.map((c) => c.text).toSet(), {'are', 'is', 'am'});
      expect(order.meaning, 'أنا من سوريا.');
      expect(order.answerWords, ['I', 'am', 'from', 'Syria']);
      expect(order.bank.map((c) => c.text).toSet(), {
        'I',
        'am',
        'from',
        'Syria',
        'is',
      });
    });

    test('the rule card reads as the summary, with no video to wait for', () {
      final grammar = lesson.grammar!;

      expect(grammar.video, isNull);
      expect(grammar.exercisesOpen, isTrue);
      expect(grammar.summary.text, startsWith('نستعمل am مع I'));
      expect(grammar.summary.rows.map((r) => r.left), [
        'I',
        'he / she / it',
        'you / we / they',
      ]);
      expect(grammar.summary.rows.first.right.single.text, 'am');
      expect(grammar.summary.rows.first.right.single.marked, isTrue);

      final example = grammar.summary.examples.first;
      expect(example.parts.map((p) => p.text).join(), 'I am a student.');
      expect(example.parts.where((p) => p.strong).map((p) => p.text), ['am']);
      expect(example.arabic, 'أنا طالب.');
      expect(example.audioUrl, endsWith('.mp3'));
    });

    test('the right answer goes as the server’s own key', () {
      final questions = _lessonJson().readList('questions')!;

      for (final (i, exercise) in lesson.exercises.indexed) {
        final draft = _rightDraft(exercise);
        final key = asJsonMap(asJsonMap(questions[i])['answerKey']);
        final sent = _sent(_lessonJson(), exercise.id, draft)!;
        final answer = asJsonMap(sent['answer']);

        expect(evaluate(exercise, draft).correct, isTrue, reason: exercise.id);
        expect(answer.keys.single, key.keys.first, reason: exercise.id);
        expect(answer.values.single, key.values.first, reason: exercise.id);
      }
    });

    test('an answer carries the lesson’s version and its time in UTC', () {
      final first = lesson.exercises.first as ChoiceExercise;

      expect(_sent(_lessonJson(), first.id, const ChoiceDraft('b')), {
        'clientAttemptId': 'attempt',
        'lessonVersionId': '01a1f24f-f2b6-7cd3-871b-7eb62e9b501b',
        'questionVersionId': first.id,
        'runId': 'run',
        'answer': {'optionId': 'b'},
        'hintsUsed': 0,
        'clientCreatedAt': '2026-11-20T14:00:00.000Z',
      });
      expect(
        _sent(
          _lessonJson(),
          first.id,
          const ChoiceDraft('b'),
          hinted: true,
        )!['hintsUsed'],
        1,
      );
    });

    test('an answer of another shape than its template isn’t sent', () {
      final first = lesson.exercises.first;

      expect(_sent(_lessonJson(), first.id, const TextDraft('is')), isNull);
      expect(_sent(_lessonJson(), 'no-such', const ChoiceDraft('a')), isNull);
    });

    test('a template this version doesn’t know is left out', () {
      final json = _lessonJson();
      asJsonMap(json.readList('questions')!.first)['template'] = 'new_one';

      expect(LessonModel(json).toEntity('seed').exercises, hasLength(5));
    });

    test('a lesson with a video can’t be read yet', () {
      final json = _lessonJson();
      asJsonMap(json['content'])
        ..['withVideo'] = true
        ..['video'] = {'id': 'v'};

      final lesson = LessonModel(json).toEntity('seed');

      expect(lesson.grammar, isNull);
      expect(lesson.exercises, hasLength(6));
    });

    test('brackets mark the letters a rule is about', () {
      final json = _lessonJson();
      asJsonMap(asJsonMap(json['content'])['ruleCard'])['forms'] = [
        ['he / she / it', 'play[s]', 'do[es] not'],
      ];

      final row = LessonModel(json).toEntity('seed').grammar!.summary.rows[0];

      expect(row.right.map((p) => (p.text, p.marked)), [
        ('play', false),
        ('s', true),
        (' do', false),
        ('es', true),
        (' not', false),
      ]);
    });

    test('words marked side by side, first and last, keep the sentence', () {
      final json = _lessonJson();
      final examples = asJsonMap(
        asJsonMap(json['content'])['ruleCard'],
      ).readList('examples')!;
      asJsonMap(examples.first)
        ..['textEn'] = 'They are not at home.'
        ..['highlight'] = [0, 1, 2, 4];

      final example = LessonModel(
        json,
      ).toEntity('seed').grammar!.summary.examples.first;

      expect(example.parts.map((p) => p.text).join(), 'They are not at home.');
      expect(example.parts.where((p) => p.strong).map((p) => p.text), [
        'They are not',
        'home.',
      ]);
    });
  });

  group('an interactive text (the dev server’s own, B-21)', () {
    late Lesson lesson;
    late ReaderContent reader;

    setUp(() {
      lesson = LessonModel(
        _data('app_lesson_interactive_text'),
      ).toEntity('seed');
      reader = lesson.reader!;
    });

    test('one sound for the lesson, and its questions after it', () {
      expect(lesson.id, '01a2160b-d9a5-7a4c-a3a5-47829fa48bc0');
      expect(lesson.grammar, isNull);
      expect(reader.video, isNull);
      expect(reader.audioUrl, endsWith('.mp3'));
      expect(reader.duration, const Duration(milliseconds: 26336));
      expect(lesson.exercises.map((e) => e.runtimeType), [
        MultipleChoiceExercise,
        ImageChoiceExercise,
        ListenChooseExercise,
        FillChoicesExercise,
        WordOrderExercise,
        MatchingExercise,
      ]);
    });

    test('its sentences, each word with its time in the sound', () {
      expect(reader.sentences.map((s) => s.id), [
        's1',
        's2',
        's3',
        's4',
        's5',
        's6',
      ]);
      final second = reader.sentences[1];
      expect(second.english, 'She has breakfast with her family.');
      expect(second.arabic, 'تتناول الفطور مع عائلتها.');
      expect(second.start, const Duration(milliseconds: 4300));
      expect(second.end, const Duration(milliseconds: 7916));
      expect(second.words[2].text, 'breakfast');
      expect(second.words[2].start, const Duration(milliseconds: 5472));
      expect(second.words[2].end, const Duration(milliseconds: 6145));
      expect(second.words.last.text, 'family.', reason: 'its full stop');
    });

    test('a sentence may have no translation, a picture, or a speaker', () {
      expect(reader.sentences.map((s) => s.arabic == null), [
        false,
        false,
        false,
        true,
        false,
        true,
      ]);
      expect(reader.sentences.map((s) => s.imageUrl != null), [
        false,
        true,
        true,
        false,
        false,
        false,
      ]);
      expect(reader.sentences[1].imageUrl, endsWith('.webp'));
      expect(reader.sentences.map((s) => s.speaker), [
        null,
        null,
        null,
        null,
        'Mum',
        null,
      ]);
    });

    test('only the sentences marked are repeated after', () {
      expect(reader.hasShadowing, isTrue);
      expect(reader.sentences.map((s) => s.shadowing), [
        true,
        false,
        true,
        false,
        true,
        false,
      ]);
    });

    test('its spans: a word, a phrasal verb, an expression', () {
      expect(reader.spans.map((s) => (s.id, s.sentenceId, s.kind, s.base)), [
        ('sp1', 's1', SpanKind.phrasalVerb, 'wake up'),
        ('sp2', 's2', SpanKind.idiom, 'have breakfast'),
        ('sp3', 's4', SpanKind.word, 'big'),
        ('sp4', 's5', SpanKind.phrasalVerb, 'turn off'),
        ('sp5', 's5', SpanKind.word, 'before'),
      ]);
      expect(reader.spans[2].arabic, 'أكبر');
      expect(reader.spans[2].note, 'bigger صيغة المقارنة من big.');
      expect(reader.spans[0].note, isNull);
    });

    test('a span’s words needn’t be side by side: turn … off', () {
      final mum = reader.sentences[4];
      ReaderSpan? spanOf(String word) =>
          reader.spanOf(mum, mum.words.firstWhere((w) => w.text == word));

      expect(spanOf('turn')?.id, 'sp4');
      expect(spanOf('off')?.id, 'sp4');
      expect(spanOf('it'), isNull, reason: 'between them, and not of them');
      expect(spanOf('Please'), isNull);
      // Its sound runs from its first word to its last, the one between
      // included (the backend's rule R197).
      final words = [
        for (final word in mum.words)
          if (reader.spans[3].wordIds.contains(word.id)) word,
      ];
      expect(words.first.start, const Duration(milliseconds: 19125));
      expect(words.last.end, const Duration(milliseconds: 20505));
    });

    test('no word can be saved from it yet', () {
      expect(reader.savesWords, isFalse);
    });

    test('a sentence with no word can’t be read, and the page says so', () {
      final json = _data('app_lesson_interactive_text');
      asJsonMap(
        asJsonMap(json['content']).readList('sentences')!.first,
      )['tokens'] = const <Object?>[];

      expect(LessonModel(json).toEntity('seed').reader, isNull);
    });

    test('the kids’ story is the same shape, a picture for each sentence', () {
      final story = LessonModel(
        _data('app_lesson_kids_story'),
      ).toEntity('seed');
      final reader = story.reader!;

      expect(reader.sentences.map((s) => s.english), [
        'This is my ball.',
        'It is on the chair.',
        'Now it is under the chair.',
        'Look! It is in the box.',
      ]);
      expect(reader.sentences.every((s) => s.imageUrl != null), isTrue);
      expect(reader.sentences.every((s) => s.arabic != null), isTrue);
      expect(reader.spans.map((s) => (s.kind, s.base, s.arabic)), [
        (SpanKind.word, 'on', 'على'),
        (SpanKind.word, 'under', 'تحت'),
      ]);
      // Its questions: three the kids' screens show, and a written gap they
      // have no screen for yet (docs/STATUS.md D-133).
      expect(story.exercises.map((e) => e.runtimeType), [
        ImageChoiceExercise,
        ListenChooseExercise,
        MatchingExercise,
        MultipleChoiceExercise,
      ]);
      expect(story.kids, isNull);
    });

    test('an interactive video has no media yet, so no reader', () {
      final json = _data('app_lesson_interactive_text');
      asJsonMap(json['content'])
        ..['type'] = 'interactive_video'
        ..['media'] = null;

      final lesson = LessonModel(json).toEntity('seed');

      expect(lesson.reader, isNull);
      expect(lesson.exercises, hasLength(6));
    });
  });

  group('a matching', () {
    Map<String, Object?> answer(PairsDraft draft, {List<int>? key}) =>
        asJsonMap(
          _sent(key == null ? _matching() : _matching(key: key), 'm', draft)!,
        );

    const all = {'one', 'two', 'three'};

    test('pairs each word with what the key gives it', () {
      final exercise =
          LessonModel(_matching()).toEntity('s').exercises.single
              as MatchingExercise;

      expect(
        {for (final pair in exercise.pairs) pair.id: pair.meaning},
        {'one': 'A', 'two': 'B', 'three': 'C'},
      );
      expect(exercise.pictures, isFalse);
    });

    test('with pictures, each word has its picture', () {
      final exercise =
          LessonModel(
                _matching(rightKind: 'image'),
              ).toEntity('s').exercises.single
              as MatchingExercise;

      expect(exercise.pictures, isTrue);
      expect(exercise.pairs.first.image, 'https://example.com/a.webp');
      expect(exercise.pairs.first.alt, 'A');
    });

    test('with no mistake, the key goes', () {
      expect(answer(const PairsDraft(total: 3, matched: all))['answer'], {
        'pairs': [2, 0, 1],
      });
    });

    test('a first wrong try goes as its two pairs changed over', () {
      final sent = answer(
        const PairsDraft(
          total: 3,
          matched: all,
          mistakes: {'one'},
          wrong: {'one': 'two'},
        ),
      );

      // "one" with B, which is "two"'s; each place still used once.
      expect(sent['answer'], {
        'pairs': [0, 2, 1],
      });
    });

    test('two mistakes never undo one another', () {
      final sent = answer(
        const PairsDraft(
          total: 3,
          matched: all,
          mistakes: {'one', 'two'},
          wrong: {'one': 'two', 'two': 'one'},
        ),
      );

      expect(sent['answer'], {
        'pairs': [0, 2, 1],
      });
    });

    test('a pair with no place in the key is left out', () {
      final exercise =
          LessonModel(
                _matching(key: const [2, 0, 9]),
              ).toEntity('s').exercises.single
              as MatchingExercise;

      expect(exercise.pairs.map((p) => p.id), ['one', 'two']);
    });
  });

  group('marking as the server does', () {
    test('an order’s words: no case, no punctuation, split at spaces', () {
      expect(orderWords(['He', 'watches', 'TV.']), ['he', 'watches', 'tv']);
      expect(orderWords(['I', 'have to', 'go!']), ['i', 'have', 'to', 'go']);
      expect(orderWords(['It’s mine.']), ['its', 'mine']);
      expect(orderWords(["It's mine."]), ['its', 'mine']);
      expect(orderWords([' ', '--.', '']), isEmpty);
    });

    WordOrderExercise order(
      List<String> chips, {
      List<String> alternatives = const [],
    }) =>
        LessonModel({
              'id': 'les',
              'versionId': 'v1',
              'versionNo': 1,
              'content': null,
              'media': const <String, Object?>{},
              'questions': [
                {
                  'versionId': 'o',
                  'template': 'word_order',
                  'instructionAr': 'a',
                  'body': {'meaningAr': 'a', 'chips': chips},
                  'answerKey': {
                    'chips': chips,
                    'alternatives': [
                      for (final alternative in alternatives)
                        alternative.split(' '),
                    ],
                  },
                },
              ],
            }).toEntity('s').exercises.single
            as WordOrderExercise;

    bool right(WordOrderExercise exercise, List<String> placed) => evaluate(
      exercise,
      SequenceDraft([
        for (final (i, text) in placed.indexed) WordChip(id: 'p$i', text: text),
      ], needed: exercise.answerWords.length),
    ).correct;

    test('an order is right as its key, or as one of the others', () {
      final tv = order(
        ['He', 'watches', 'TV', 'every', 'night.'],
        alternatives: ['every night he watches tv'],
      );

      expect(right(tv, ['He', 'watches', 'TV', 'every', 'night.']), isTrue);
      expect(right(tv, ['every', 'night.', 'He', 'watches', 'TV']), isTrue);
      expect(right(tv, ['He', 'watch', 'TV', 'every', 'night.']), isFalse);
      expect(right(tv, ['TV', 'watches', 'He', 'every', 'night.']), isFalse);
    });

    test('a card of two words counts as two', () {
      final go = order(
        ['I', 'have to', 'go', 'now.'],
        alternatives: ['now i have to go'],
      );

      expect(right(go, ['now.', 'I', 'have to', 'go']), isTrue);
    });

    test('a blank takes its word letter for letter', () {
      final json = _lessonJson();
      final gap = asJsonMap(json.readList('questions')![2]);
      asJsonMap(gap['body'])
        ..['sentence'] = 'He ___ and she ___.'
        ..['gapCount'] = 2
        ..['chips'] = ['plays', 'watches', 'Plays'];
      gap['answerKey'] = {
        'gaps': ['plays', 'watches'],
      };
      final exercise =
          LessonModel(json).toEntity('s').exercises[2] as FillChoicesExercise;

      List<bool> marked(List<String> words) =>
          (evaluate(
                    exercise,
                    SlotsDraft([
                      for (final (i, word) in words.indexed)
                        WordChip(id: 'p$i', text: word),
                    ]),
                  )
                  as SlotsEvaluation)
              .slots;

      expect(marked(['plays', 'watches']), [true, true]);
      expect(marked(['Plays', 'watches']), [false, true]);
      expect(marked(['watches', 'plays']), [false, false]);
      expect(exercise.bank.map((c) => c.text).toSet(), {
        'plays',
        'watches',
        'Plays',
      });
    });
  });

  group('the sync’s reply', () {
    List<SyncResultModel> results(String name) =>
        syncResultsFromJson(_data(name));

    test('an answer kept, with the server’s marking', () {
      final result = results('app_sync_accepted').single;

      expect(result.attemptId, '1de901f5-2752-41cd-8fe4-ca1f0b643bed');
      expect(result.status, SyncStatus.accepted);
      expect(result.correct, isTrue);
    });

    test('an answer it had already, with its first marking', () {
      final result = results('app_sync_duplicate').single;

      expect(result.status, SyncStatus.duplicate);
      expect(result.correct, isTrue);
    });

    test('answers refused one by one, each with its code', () {
      final all = results('app_sync_mixed');

      expect(all.map((r) => r.status), [
        SyncStatus.accepted,
        SyncStatus.rejected,
        SyncStatus.rejected,
        SyncStatus.rejected,
      ]);
      expect(all.first.correct, isFalse);
      expect(all.skip(1).map((r) => r.errorCode), [
        'question.answer_invalid',
        'question.version_unknown',
        'validation.failed',
      ]);
    });

    test('what else it carries is left alone', () {
      final all = results('app_sync_lesson_completed');

      expect(all, hasLength(5));
      expect(all.every((r) => r.status == SyncStatus.accepted), isTrue);
    });

    test('a matching that isn’t one to one is refused', () {
      final all = results('app_sync_matching_and_order');

      // [1,0,2], [0,0,2], [0,1,5], [0,1], then three orders of words.
      expect(all.map((r) => (r.status, r.correct)), [
        (SyncStatus.accepted, false),
        (SyncStatus.rejected, null),
        (SyncStatus.rejected, null),
        (SyncStatus.rejected, null),
        (SyncStatus.accepted, true),
        (SyncStatus.accepted, false),
        (SyncStatus.accepted, false),
      ]);
    });

    test('a status from a later server is unknown, with its name', () {
      final result = SyncResultModel.fromJson(const {
        'clientAttemptId': 'a',
        'status': 'pending_ai',
        'isCorrect': null,
      });

      expect(result.status, SyncStatus.unknown);
      expect(result.statusName, 'pending_ai');
    });

    test('a request refused whole names the answer by its place', () {
      final error = ApiException.fromResponse(
        statusCode: 400,
        body: _body('app_sync_validation_failed'),
      );

      expect(error.code, 'validation.failed');
      expect(error.fields, ['attempts[0].clientAttemptId']);
      expect(error.traceId, isNotEmpty);
    });
  });
}
