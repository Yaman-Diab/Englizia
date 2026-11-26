import 'package:englizia/core/network/json_reader.dart';

/// The server's lesson (`LessonContentDto`, docs/api/lessons.md) put in the
/// shape the app's readers take, so one reader serves it and the lesson types
/// the server doesn't have yet, which come from the mock in that shape.

/// Whether [json] is a lesson as the server sends it.
bool isServerLesson(Map<String, Object?> json) =>
    json['versionId'] is String && json['questions'] is List;

/// The server's templates, by the names the app's reader knows.
const _templates = {
  'multiple_choice': 'multipleChoice',
  'picture_choice': 'imageChoice',
  'listen_choose': 'listenChoose',
  'gap_choice': 'fillChoices',
  'word_order': 'wordOrder',
  'matching': 'matching',
};

Map<String, Object?> lessonFromServer(Map<String, Object?> json) {
  final media = json.readMap('media') ?? const <String, Object?>{};
  String? url(String? id) =>
      id == null ? null : media.readMap(id)?.readString('url');
  return {
    'id': json.readString('id'),
    'version': json.readInt('versionNo'),
    'versionId': json.readString('versionId'),
    'title': json.readString('titleAr'),
    'bookRef': ?_bookPage(json.readMap('bookPages')),
    'content': ?_content(json.readMap('content'), url),
    'reader': ?_reader(json.readMap('content'), url),
    'exercises': [
      for (final question in json.readList('questions') ?? const <Object?>[])
        if (question is Map) _question(question.cast(), url),
    ],
  };
}

/// The lesson's book page: the first of its pages, as the app shows one.
Map<String, Object?>? _bookPage(Map<String, Object?>? pages) =>
    switch (pages?.readInt('from')) {
      final page? => {'page': page},
      null => null,
    };

Map<String, Object?>? _content(
  Map<String, Object?>? content,
  String? Function(String?) url,
) {
  final card = content?.readMap('ruleCard');
  if (content == null || card == null) return null;
  // ASSUMPTION(api): no lesson with a video is published yet, so the shape of
  // `video` isn't known (docs/api/lessons.md, question 1). One that has it
  // comes with no watch share here, and the page says it can't be read.
  final video = content.readBool('withVideo') ?? false;
  return {
    'summary': {
      'ar': card.readString('summaryAr'),
      'table': [
        for (final row in card.readList('forms') ?? const <Object?>[])
          if (row case [final String left, ...final rest])
            {
              'left': left,
              'right': _marked(rest.whereType<String>().join(' ')),
            },
      ],
      'examples': [
        for (final example in card.readList('examples') ?? const <Object?>[])
          if (example is Map) _example(example.cast(), url),
      ],
    },
    if (!video) ...{'requiredWatchPercent': 0, 'exercisesOpen': true},
  };
}

/// The server's span kinds, by the names the app's reader knows.
const _spanKinds = {
  'word': 'word',
  'phrasal_verb': 'phrasalVerb',
  'expression': 'idiom',
};

/// An interactive text (the backend's note B-21): one sound for the lesson,
/// each sentence and word with its time in it, and the spans a sentence
/// marks. A sentence may come with no translation. Saving a span's word has
/// no call yet (N-5), so the reader offers none. An interactive video has no
/// media before the server takes videos (N-9), and can't be shown.
Map<String, Object?>? _reader(
  Map<String, Object?>? content,
  String? Function(String?) url,
) {
  if (content?.readString('type') != 'interactive_text') return null;
  final media = content?.readMap('media');
  final sentences = [
    for (final sentence in content?.readList('sentences') ?? const <Object?>[])
      if (sentence is Map) sentence.cast<String, Object?>(),
  ];
  return {
    'audio': {
      'url': url(media?.readString('mediaId')),
      'durationMs': media?.readInt('durationMs'),
    },
    'savesWords': false,
    'sentences': [
      for (final sentence in sentences)
        {
          'id': sentence.readString('id'),
          'ar': ?sentence.readString('textAr'),
          'speaker': ?sentence.readString('speaker'),
          'image': ?url(sentence.readString('imageMediaId')),
          'shadowing': sentence.readBool('shadowing') ?? false,
          'words': sentence.readList('tokens'),
        },
    ],
    'spans': [
      for (final sentence in sentences)
        for (final span in sentence.readList('spans') ?? const <Object?>[])
          if (span is Map)
            {
              'id': span['id'],
              'sentenceId': sentence.readString('id'),
              'wordIds': span['tokenIds'],
              'kind': _spanKinds[span['kind']] ?? span['kind'],
              'base': span['lemma'],
              'ar': span['textAr'],
              'note': ?span['noteAr'],
            },
    ],
  };
}

final _mark = RegExp(r'\[([^\]]*)\]');

/// "play[s]": the letters between brackets are the ones the rule is about.
List<Map<String, Object?>> _marked(String text) {
  final parts = <Map<String, Object?>>[];
  var from = 0;
  for (final match in _mark.allMatches(text)) {
    if (match.start > from) {
      parts.add({'text': text.substring(from, match.start)});
    }
    parts.add({'text': match.group(1), 'marked': true});
    from = match.end;
  }
  if (from < text.length) parts.add({'text': text.substring(from)});
  return parts;
}

/// `highlight` counts the sentence's words from 0, split at its spaces. Words
/// that follow one another the same way make one part.
Map<String, Object?> _example(
  Map<String, Object?> json,
  String? Function(String?) url,
) {
  final words = (json.readString('textEn') ?? '').split(' ');
  final strong = {
    for (final index in json.readList('highlight') ?? const <Object?>[])
      if (index is int) index,
  };
  final parts = <Map<String, Object?>>[];
  for (final (i, word) in words.indexed) {
    final marked = strong.contains(i);
    final last = parts.lastOrNull;
    if (last == null) {
      parts.add({'text': word, if (marked) 'strong': true});
    } else if ((last['strong'] == true) == marked) {
      last['text'] = '${last['text']} $word';
    } else if (marked) {
      // The space between a plain part and a marked one stays plain.
      last['text'] = '${last['text']} ';
      parts.add({'text': word, 'strong': true});
    } else {
      parts.add({'text': ' $word'});
    }
  }
  return {
    'en': parts,
    'ar': json.readString('translationAr'),
    'audio': ?url(json.readString('audioMediaId')),
  };
}

/// A unit test's questions (B-33b), in the shape a lesson's take: they come
/// with no `answerKey`, hint or explanation, and in the learner's own order,
/// which the answer is given in. The app's reader needs a key, so each gets
/// one that keeps the cards where they came: the first options or cards.
/// Nothing marks them on the phone; the server does.
Map<String, Object?> unitTestQuestion(
  Map<String, Object?> json,
  String? Function(String?) url,
) {
  final body = json.readMap('body') ?? const <String, Object?>{};
  final chips = [
    for (final chip in body.readList('chips') ?? const <Object?>[])
      if (chip is String) chip,
  ];
  final options = body.readList('options') ?? const <Object?>[];
  final firstOption = options.isEmpty
      ? null
      : asJsonMap(options.first).readString('id');
  final key = switch (json.readString('template')) {
    'gap_choice' => {
      'gaps': chips.take(body.readInt('gapCount') ?? 1).toList(),
    },
    'word_order' => {
      'chips': chips.take(1).toList(),
      'alternatives': const <Object?>[],
    },
    'matching' => {
      'pairs': [
        for (var i = 0; i < (body.readList('left')?.length ?? 0); i++) i,
      ],
    },
    _ => {'optionId': firstOption},
  };
  return {
    ..._question({...json, 'answerKey': key}, url),
    'keepOrder': true,
  };
}

/// A lesson of the server's from a unit test: the app's reader takes it.
Map<String, Object?> lessonFromUnitTest(Map<String, Object?> json) {
  final media = json.readMap('media') ?? const <String, Object?>{};
  String? url(String? id) =>
      id == null ? null : media.readMap(id)?.readString('url');
  return {
    'id': json.readString('id'),
    'version': json.readInt('versionNo') ?? 1,
    'versionId': json.readString('versionId'),
    'exercises': [
      for (final question in json.readList('questions') ?? const <Object?>[])
        if (question is Map) unitTestQuestion(question.cast(), url),
    ],
  };
}

/// A question's id is its version's: the server knows no other, and an answer
/// names it (`questionVersionId`).
Map<String, Object?> _question(
  Map<String, Object?> json,
  String? Function(String?) url,
) {
  final template = json.readString('template');
  final body = json.readMap('body') ?? const <String, Object?>{};
  final key = json.readMap('answerKey') ?? const <String, Object?>{};
  final hint = json.readString('hintAr');
  final explanation = json.readString('explanationAr');
  return {
    'id': json.readString('versionId'),
    'template': _templates[template] ?? template,
    'instructionAr': json.readString('instructionAr'),
    if (hint != null) 'hint': {'ar': hint},
    if (explanation != null) 'explanation': {'ar': explanation},
    ...switch (template) {
      'multiple_choice' => {
        'prompt': {'en': body.readString('prompt')},
        'options': _options(body, url),
        'answer': key.readString('optionId'),
      },
      'picture_choice' => {
        'prompt': {
          'en': body.readString('prompt'),
          'audio': ?url(body.readString('promptAudioMediaId')),
        },
        'options': _options(body, url),
        'answer': key.readString('optionId'),
      },
      'listen_choose' => {
        'prompt': {
          'audio': ?url(body.readString('audioMediaId')),
          'transcript': ?body.readString('transcript'),
        },
        'options': _options(body, url),
        'answer': key.readString('optionId'),
      },
      'gap_choice' => _gaps(body, key),
      'word_order' => _order(body, key),
      'matching' => _pairs(body, key, url),
      _ => const <String, Object?>{},
    },
  };
}

List<Map<String, Object?>> _options(
  Map<String, Object?> body,
  String? Function(String?) url,
) => [
  for (final option in body.readList('options') ?? const <Object?>[])
    if (option is Map)
      {
        'id': option['id'],
        'text': ?option['text'],
        'image': ?url(
          option.cast<String, Object?>().readString('imageMediaId'),
        ),
      },
];

List<String> _strings(List<Object?>? values) => [
  for (final value in values ?? const <Object?>[])
    if (value is String) value,
];

/// What is in [all] and not among [used], each as often as it is left over:
/// the cards that belong to no answer.
List<Map<String, Object?>> _extra(List<String> all, List<String> used) {
  final left = [...used];
  return [
    for (final text in all)
      if (!left.remove(text)) {'text': text},
  ];
}

Map<String, Object?> _gaps(
  Map<String, Object?> body,
  Map<String, Object?> key,
) {
  final gaps = _strings(key.readList('gaps'));
  return {
    'prompt': {'en': body.readString('sentence')},
    'blanks': [
      for (final gap in gaps) {'answer': gap},
    ],
    'distractors': _extra(_strings(body.readList('chips')), gaps),
  };
}

Map<String, Object?> _order(
  Map<String, Object?> body,
  Map<String, Object?> key,
) {
  final chips = _strings(key.readList('chips'));
  return {
    'meaningAr': body.readString('meaningAr'),
    'answer': chips.join(' '),
    'chips': chips,
    // Each comes as its words, ready to compare.
    'alternatives': [
      for (final alternative in key.readList('alternatives') ?? const [])
        if (alternative is List) _strings(alternative).join(' '),
    ],
    'distractors': _extra(_strings(body.readList('chips')), chips),
  };
}

/// `answerKey.pairs[i]` is the place in `right` of what goes with `left[i]`.
/// It stays on each pair (`rightIndex`), as an answer is sent in those places.
Map<String, Object?> _pairs(
  Map<String, Object?> body,
  Map<String, Object?> key,
  String? Function(String?) url,
) {
  final pictures = body.readString('rightKind') == 'image';
  final left = _strings(body.readList('left'));
  final right = body.readList('right') ?? const <Object?>[];
  final places = key.readList('pairs') ?? const <Object?>[];
  return {
    'kind': pictures ? 'image' : 'text',
    'pairs': [
      for (final (i, word) in left.indexed)
        if (i < places.length)
          if (places[i] case final int place
              when place >= 0 && place < right.length)
            if (right[place] case final Map<Object?, Object?> other)
              {
                'left': word,
                'rightIndex': place,
                if (pictures) ...{
                  'rightImage': ?url(
                    other.cast<String, Object?>().readString('imageMediaId'),
                  ),
                  'rightAlt': ?other['text'],
                } else
                  'right': other['text'],
              },
    ],
  };
}
