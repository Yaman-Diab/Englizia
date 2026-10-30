import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/stable_order.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/lessons.md).

/// The lesson as it came, so it can be kept on the phone as it is.
final class LessonModel {
  const LessonModel(this.json);

  final Map<String, Object?> json;

  /// [seed] is this learner's, for the order of the options.
  Lesson toEntity(String seed) {
    final id = json.readString('id');
    final version = json.readInt('version');
    if (id == null || version == null) {
      throw const FormatException('Lesson: no id or version');
    }
    final exercises = <Exercise>[];
    var broken = 0;
    for (final question in json.readList('exercises') ?? const <Object?>[]) {
      try {
        if (_exercise(asJsonMap(question), seed) case final exercise?) {
          exercises.add(exercise);
        }
      } on FormatException catch (error, stackTrace) {
        // One bad question must not leave the learner stuck on the lesson.
        broken++;
        AppLogger.error(error, stackTrace, 'Lesson $id: a question skipped');
      }
    }
    if (exercises.isEmpty && broken > 0) {
      throw const FormatException('Lesson: no question could be read');
    }
    return Lesson(id: id, version: version, exercises: exercises);
  }
}

/// Null for what isn't shown here: a template this version doesn't know, which
/// the server should have hidden (S §7.3), and review-only questions.
Exercise? _exercise(Map<String, Object?> json, String seed) {
  if (json.readBool('reviewOnly') ?? false) return null;
  final template = json.readString('template');
  if (template == null) throw const FormatException('Exercise: no template');
  if (!_templates.contains(template)) return null;
  final id = json.readString('id');
  final instruction = json.readString('instructionAr');
  if (id == null || instruction == null) {
    throw const FormatException('Exercise: no id or instruction');
  }
  final prompt = json.readMap('prompt') ?? const <String, Object?>{};
  final hint = json.readMap('hint')?.readString('ar');
  final bookReference = _bookReference(json.readMap('bookRef'));
  final key = '$seed:$id';
  return switch (template) {
    'fillChoices' => _fillChoices(
      json,
      prompt,
      id: id,
      instruction: instruction,
      key: key,
      hint: hint,
      bookReference: bookReference,
    ),
    'wordOrder' => _wordOrder(
      json,
      id: id,
      instruction: instruction,
      key: key,
      hint: hint,
      bookReference: bookReference,
    ),
    'matching' => _matching(
      json,
      id: id,
      instruction: instruction,
      key: key,
      hint: hint,
      bookReference: bookReference,
    ),
    _ => _choice(
      template,
      json,
      prompt,
      id: id,
      instruction: instruction,
      key: key,
      hint: hint,
      bookReference: bookReference,
    ),
  };
}

const _templates = {
  'multipleChoice',
  'imageChoice',
  'listenChoose',
  'fillChoices',
  'wordOrder',
  'matching',
};

ChoiceExercise _choice(
  String template,
  Map<String, Object?> json,
  Map<String, Object?> prompt, {
  required String id,
  required String instruction,
  required String key,
  required String? hint,
  required BookReference? bookReference,
}) {
  final answer = json.readString('answer');
  final options = [
    for (final option in json.readList('options') ?? const <Object?>[])
      _option(asJsonMap(option)),
  ];
  if (options.isEmpty || !options.any((o) => o.id == answer)) {
    throw const FormatException('Exercise: no options, or no right one');
  }
  final shown = stableOrder(options, key);
  return switch (template) {
    'multipleChoice' => _multipleChoice(
      id: id,
      instruction: instruction,
      options: shown,
      answer: answer!,
      hint: hint,
      bookReference: bookReference,
      sentence: prompt.readString('en'),
    ),
    'imageChoice' => ImageChoiceExercise(
      id: id,
      instruction: instruction,
      options: shown,
      answerId: answer!,
      word: _required(prompt.readString('en')),
      audioUrl: prompt.readString('audio'),
      hint: hint,
      bookReference: bookReference,
    ),
    _ => ListenChooseExercise(
      id: id,
      instruction: instruction,
      options: shown,
      answerId: answer!,
      audioUrl: _required(prompt.readString('audio')),
      hint: hint,
      bookReference: bookReference,
    ),
  };
}

FillChoicesExercise _fillChoices(
  Map<String, Object?> json,
  Map<String, Object?> prompt, {
  required String id,
  required String instruction,
  required String key,
  required String? hint,
  required BookReference? bookReference,
}) {
  final segments = [
    for (final part in _required(prompt.readString('en')).split(_blank))
      part.trim(),
  ];
  final blanks = [
    for (final blank in json.readList('blanks') ?? const <Object?>[])
      _fillBlank(asJsonMap(blank)),
  ];
  if (blanks.isEmpty || segments.length != blanks.length + 1) {
    throw const FormatException('Exercise: blanks do not fit the sentence');
  }
  return FillChoicesExercise(
    id: id,
    instruction: instruction,
    segments: segments,
    blanks: blanks,
    bank: _bank([
      for (final blank in blanks) blank.answer,
      ..._distractors(json),
    ], key),
    hint: hint,
    bookReference: bookReference,
  );
}

FillBlank _fillBlank(Map<String, Object?> json) => FillBlank(
  answer: _required(json.readString('answer')),
  alternatives: _strings(json.readList('alternatives')),
);

WordOrderExercise _wordOrder(
  Map<String, Object?> json, {
  required String id,
  required String instruction,
  required String key,
  required String? hint,
  required BookReference? bookReference,
}) {
  final answer = _required(json.readString('answer'));
  final chips = _strings(json.readList('chips'));
  final words = chips.isEmpty ? answer.split(' ') : chips;
  return WordOrderExercise(
    id: id,
    instruction: instruction,
    meaning: _required(json.readString('meaningAr')),
    answer: answer,
    answerWords: words,
    alternatives: _strings(json.readList('alternatives')),
    bank: _bank([...words, ..._distractors(json)], key),
    hint: hint,
    bookReference: bookReference,
  );
}

MatchingExercise _matching(
  Map<String, Object?> json, {
  required String id,
  required String instruction,
  required String key,
  required String? hint,
  required BookReference? bookReference,
}) {
  final pictures = json.readString('kind') == 'image';
  final pairs = [
    for (final pair in json.readList('pairs') ?? const <Object?>[])
      _pair(asJsonMap(pair), pictures: pictures),
  ];
  if (pairs.isEmpty || pairs.map((p) => p.id).toSet().length != pairs.length) {
    throw const FormatException('Exercise: no pairs, or two the same');
  }
  return MatchingExercise(
    id: id,
    instruction: instruction,
    pairs: pairs,
    meaningsShown: stableOrder(pairs, '$key:meanings'),
    wordsShown: stableOrder(pairs, '$key:words'),
    pictures: pictures,
    hint: hint,
    bookReference: bookReference,
  );
}

MatchPair _pair(Map<String, Object?> json, {required bool pictures}) => pictures
    ? MatchPair(
        id: _required(json.readString('left')),
        image: _required(json.readString('rightImage')),
        alt: json.readString('rightAlt') ?? '',
      )
    : MatchPair(
        id: _required(json.readString('left')),
        meaning: _required(json.readString('right')),
      );

List<String> _distractors(Map<String, Object?> json) => [
  for (final distractor in json.readList('distractors') ?? const <Object?>[])
    _required(asJsonMap(distractor).readString('text')),
];

/// The cards in this learner's order. Ids go by position, as a word may repeat.
List<WordChip> _bank(List<String> words, String key) => stableOrder([
  for (final (i, word) in words.indexed) WordChip(id: 'c$i', text: word),
], key);

List<String> _strings(List<Object?>? values) => [
  for (final value in values ?? const <Object?>[])
    if (value is String) value,
];

MultipleChoiceExercise _multipleChoice({
  required String id,
  required String instruction,
  required List<ExerciseOption> options,
  required String answer,
  required String? hint,
  required BookReference? bookReference,
  required String? sentence,
}) {
  final parts = _required(sentence).split(_blank);
  if (parts.length != 2) {
    throw const FormatException('Exercise: not one blank in the sentence');
  }
  return MultipleChoiceExercise(
    id: id,
    instruction: instruction,
    options: options,
    answerId: answer,
    before: parts.first.trim(),
    after: parts.last.trim(),
    hint: hint,
    bookReference: bookReference,
  );
}

const _blank = '___';

String _required(String? value) =>
    value ?? (throw const FormatException('Exercise: a field is missing'));

BookReference? _bookReference(Map<String, Object?>? json) {
  final page = json?.readInt('page');
  final exercise = json?.readInt('exercise');
  return page == null || exercise == null
      ? null
      : BookReference(page: page, exercise: exercise);
}

ExerciseOption _option(Map<String, Object?> json) {
  final id = json.readString('id');
  if (id == null) throw const FormatException('Exercise: an option with no id');
  return ExerciseOption(
    id: id,
    text: json.readString('text') ?? '',
    image: json.readString('image') ?? '',
    alt: json.readString('alt') ?? '',
  );
}

/// An attempt as it is kept and sent, with its stable [attemptId].
Map<String, Object?> attemptToJson(ExerciseAttempt attempt, String attemptId) =>
    {
      'attemptId': attemptId,
      'lessonVersion': attempt.lessonVersion,
      'questionId': attempt.questionId,
      'answer': switch (attempt.draft) {
        ChoiceDraft(:final optionId) => {'optionId': optionId},
        SlotsDraft(:final chips) => {
          'words': [for (final chip in chips) chip?.text],
        },
        SequenceDraft(:final chips) => {
          'words': [for (final chip in chips) chip.text],
        },
        PairsDraft(:final mistakes) => {'mistakes': mistakes.toList()},
      },

      'hinted': attempt.hinted,
    };

/// What is kept on the phone: each lesson's progress, and the answers not on
/// the server yet.
final class LessonStoreModel {
  LessonStoreModel({
    Map<String, Map<String, Object?>>? lessons,
    List<Map<String, Object?>>? unsent,
  }) : lessons = lessons ?? {},
       unsent = unsent ?? [];

  factory LessonStoreModel.fromJson(Map<String, Object?> json) =>
      LessonStoreModel(
        lessons: {
          for (final entry
              in (json.readMap('lessons') ?? const <String, Object?>{}).entries)
            entry.key: asJsonMap(entry.value),
        },
        unsent: [
          for (final answer in json.readList('unsent') ?? const <Object?>[])
            asJsonMap(answer),
        ],
      );

  final Map<String, Map<String, Object?>> lessons;

  /// `{lessonId, request}`, in the order to send them.
  final List<Map<String, Object?>> unsent;

  ExerciseProgress progress(String lessonId) {
    final lesson = lessons[lessonId];
    if (lesson == null) return const ExerciseProgress();
    return ExerciseProgress(
      done: _ids(lesson.readList('done')),
      hinted: _ids(lesson.readList('hinted')),
    );
  }

  static Set<String> _ids(List<Object?>? ids) => {
    for (final id in ids ?? const <Object?>[]) ?id as String?,
  };

  void setProgress(String lessonId, ExerciseProgress progress) =>
      lessons[lessonId] = {
        'done': progress.done.toList(),
        'hinted': progress.hinted.toList(),
      };

  Map<String, Object?> toJson() => {'lessons': lessons, 'unsent': unsent};
}
