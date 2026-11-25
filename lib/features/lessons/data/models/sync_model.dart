import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';

/// `POST /api/v1/app/sync` (docs/api/lessons.md): the answers kept on the
/// phone, and what the server says of each.

/// The most hints an answer may say it used; more is refused.
const _maxHints = 10;

/// An answer as the sync takes it, built once and kept as it is: its id, run
/// and time never change however often it is sent. Null for a template the
/// server doesn't mark yet, which is neither kept nor sent.
///
/// [lesson] is the lesson in the app's own shape, as the learner saw it.
Map<String, Object?>? syncAttemptToJson(
  ExerciseAttempt attempt, {
  required Map<String, Object?> lesson,
  required String attemptId,
  required String runId,
  required DateTime at,
}) {
  final question = [
    for (final question in lesson.readList('exercises') ?? const <Object?>[])
      if (question is Map && question['id'] == attempt.questionId)
        question.cast<String, Object?>(),
  ].firstOrNull;
  if (question == null) return null;
  final answer = serverAnswerOf(question, attempt.draft);
  if (answer == null) return null;
  return {
    'clientAttemptId': attemptId,
    'lessonVersionId':
        lesson.readString('versionId') ?? '${attempt.lessonVersion}',
    'questionVersionId': attempt.questionId,
    'runId': runId,
    'answer': answer,
    // The app has one hint a question, opened or not.
    'hintsUsed': (attempt.hinted ? 1 : 0).clamp(0, _maxHints),
    'clientCreatedAt': syncTime(at),
  };
}

/// [draft] as the server takes an answer to [question] (in the app's own
/// shape), in the sync and in a unit test alike; null for a template it
/// doesn't mark.
Map<String, Object?>? serverAnswerOf(
  Map<String, Object?> question,
  ExerciseDraft draft,
) => switch ((question.readString('template'), draft)) {
  ('multipleChoice' || 'imageChoice' || 'listenChoose', final ChoiceDraft d) =>
    {'optionId': d.optionId},
  // Each card's text as it came: the server compares it letter for letter.
  ('fillChoices', final SlotsDraft d) => {
    'gaps': [for (final chip in d.chips) chip?.text ?? ''],
  },
  ('wordOrder', final SequenceDraft d) => {
    'chips': [for (final chip in d.chips) chip.text],
  },
  ('matching', final PairsDraft d) => {'pairs': _places(question, d)},
  ('matching', final LinksDraft d) => {'pairs': _linked(question, d)},
  _ => null,
};

/// For each word, in the order it came, the place of what the learner put it
/// with, among what came on the other side.
List<int> _linked(Map<String, Object?> question, LinksDraft draft) {
  final pairs = [
    for (final pair in question.readList('pairs') ?? const <Object?>[])
      if (pair is Map) pair.cast<String, Object?>(),
  ];
  final place = {
    for (final (i, pair) in pairs.indexed)
      pair.readString('left'): pair.readInt('rightIndex') ?? i,
  };
  return [
    for (final pair in pairs) place[draft.links[pair.readString('left')]] ?? -1,
  ];
}

/// The phone's clock in UTC, ending in `Z`: the server refuses any other.
String syncTime(DateTime at) => at.toUtc().toIso8601String();

/// For each word, in the lesson's order, the place of what it was put with.
///
/// The app corrects each pair as it is made, so the pairs always end right,
/// while the server marks one whole answer and takes only one where each place
/// is used once. So a first wrong try is sent as its two pairs changed over:
/// the word has what the learner gave it, and the answer is still one to one.
List<int> _places(Map<String, Object?> question, PairsDraft draft) {
  final pairs = [
    for (final pair in question.readList('pairs') ?? const <Object?>[])
      if (pair is Map) pair.cast<String, Object?>(),
  ];
  final right = [
    for (final (i, pair) in pairs.indexed) pair.readInt('rightIndex') ?? i,
  ];
  final places = [...right];
  final at = {
    for (final (i, pair) in pairs.indexed) pair.readString('left'): i,
  };
  for (final MapEntry(key: word, value: other) in draft.wrong.entries) {
    final i = at[word];
    final j = at[other];
    // Each pair changes over once at most, or two mistakes could undo
    // one another and the answer would read as right.
    if (i == null || j == null || i == j) continue;
    if (places[i] != right[i] || places[j] != right[j]) continue;
    places[i] = right[j];
    places[j] = right[i];
  }
  return places;
}

/// What the server did with one answer.
enum SyncStatus {
  /// Kept now, and marked.
  accepted,

  /// Kept before: the reply carries its first marking.
  duplicate,

  /// Refused for good, and not kept.
  rejected,

  /// A status this version doesn't know. The server has decided all the same.
  unknown,
}

final class SyncResultModel {
  const SyncResultModel({
    required this.attemptId,
    required this.status,
    this.statusName,
    this.correct,
    this.errorCode,
  });

  factory SyncResultModel.fromJson(Map<String, Object?> json) {
    final name = json.readString('status');
    return SyncResultModel(
      attemptId: json.readString('clientAttemptId') ?? '',
      status: switch (name) {
        'accepted' => SyncStatus.accepted,
        'duplicate' => SyncStatus.duplicate,
        'rejected' => SyncStatus.rejected,
        _ => SyncStatus.unknown,
      },
      statusName: name,
      correct: json.readBool('isCorrect'),
      errorCode: json.readMap('error')?.readString('code'),
    );
  }

  /// The id the phone gave the answer (`clientAttemptId`).
  final String attemptId;
  final SyncStatus status;
  final String? statusName;

  /// The server's marking; null when it kept none.
  final bool? correct;
  final String? errorCode;
}

/// The reply's results, one for each answer sent. What else it carries
/// (`lessons`, `units`, `levels`, and whatever is added later) is left alone.
List<SyncResultModel> syncResultsFromJson(Map<String, Object?> json) => [
  for (final result in json.readList('attempts') ?? const <Object?>[])
    if (result is Map) SyncResultModel.fromJson(result.cast()),
];
