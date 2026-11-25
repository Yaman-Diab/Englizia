import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/data/models/server_lesson.dart';
import 'package:englizia/features/lessons/data/models/server_unit.dart';
import 'package:englizia/features/lessons/data/models/sync_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/unit_test.dart';

/// A unit's test as `GET /api/v1/app/unit-tests/{id}` sends it
/// (docs/api/unit-tests.md).
final class UnitTestModel {
  const UnitTestModel(this.json);

  final Map<String, Object?> json;

  /// Its questions in the app's own shape, which the answers are built from.
  Map<String, Object?> get lesson => lessonFromUnitTest(json);

  UnitTest toEntity(String seed) {
    final id = json.readString('id');
    final versionId = json.readString('versionId');
    if (id == null || versionId == null) {
      throw const FormatException('Unit test: no id or version');
    }
    return UnitTest(
      id: id,
      unitId: json.readString('unitId') ?? '',
      versionId: versionId,
      status: unitTestStatusFromJson(json),
      questions: LessonModel(lesson).toEntity(seed).exercises,
    );
  }

  /// `POST …/submissions`: one answer for each question, under [submissionId].
  /// A question left with no answer the server takes is left out, and the
  /// server refuses the whole (`unit_test.answers_invalid`): the page sends
  /// only when every question has one.
  Map<String, Object?> submission(
    Map<String, ExerciseDraft> answers, {
    required String submissionId,
  }) => {
    'clientSubmissionId': submissionId,
    'versionId': json.readString('versionId'),
    'answers': [
      for (final question in lesson.readList('exercises') ?? const <Object?>[])
        if (question is Map)
          if (answers[question['id']] case final draft?)
            if (serverAnswerOf(question.cast(), draft) case final answer?)
              {'questionVersionId': question['id'], 'answer': answer},
    ],
  };
}

/// A test's state, from the map's `units[].test` or the test itself.
UnitTestStatus unitTestStatusFromJson(Map<String, Object?> json) =>
    UnitTestStatus(
      state: switch (json.readString('state')) {
        'available' => UnitTestState.available,
        'cooldown' => UnitTestState.cooldown,
        'passed' => UnitTestState.passed,
        _ => UnitTestState.locked,
      },
      questionCount: json.readInt('questionCount') ?? 0,
      passPercent: json.readInt('passPercent') ?? 0,
      bestPercent: json.readInt('bestPercent'),
      retryAt: json.readDateTime('retryAvailableAt'),
    );

/// What `POST …/submissions` answers.
UnitTestResult unitTestResultFromJson(
  Map<String, Object?> json, {
  required int passPercent,
}) {
  final questionCount = json.readInt('questionCount');
  final percent = json.readInt('percent');
  final passed = json.readBool('passed');
  if (questionCount == null || percent == null || passed == null) {
    throw const FormatException('Unit test result: incomplete');
  }
  return UnitTestResult(
    correct: json.readInt('correct') ?? 0,
    questionCount: questionCount,
    percent: percent,
    passed: passed,
    passPercent: passPercent,
    bestPercent: json.readInt('bestPercent'),
    retryAt: json.readDateTime('retryAvailableAt'),
    marks: [
      for (final mark in json.readList('questions') ?? const <Object?>[])
        if (mark is Map) mark['isCorrect'] == true,
    ],
    suggestion: levelSuggestionFromJson(json.readMap('levelCheck')),
  );
}

/// The map's or a test's `levelCheck`; null with none, one that suggests no
/// move (`direction: none`), or one that can't be read.
LevelSuggestion? levelSuggestionFromJson(Map<String, Object?>? json) {
  final id = json?.readString('id');
  final level = _level(json?.readMap('level'));
  final suggested = _level(json?.readMap('suggestedLevel'));
  final up = switch (json?.readString('direction')) {
    'up' => true,
    'down' => false,
    _ => null,
  };
  if (json == null ||
      id == null ||
      level == null ||
      suggested == null ||
      up == null) {
    return null;
  }
  return LevelSuggestion(
    id: id,
    up: up,
    percent: json.readInt('percent') ?? 0,
    level: level,
    suggested: suggested,
  );
}

LevelName? _level(Map<String, Object?>? json) {
  final id = json?.readString('id');
  if (id == null) return null;
  final names = levelNames(json);
  return LevelName(id: id, label: names.label, name: names.name);
}
