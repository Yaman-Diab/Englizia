import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/concepts.md).

String _required(String? value) =>
    value ?? (throw const FormatException('Concept: a field is missing'));

DateTime? _date(String? value) =>
    value == null ? null : DateTime.tryParse(value);

/// `GET /api/v1/app/concepts`, and the copy kept on the phone, which is the
/// same JSON.
final class ConceptBankModel {
  const ConceptBankModel(this.json);

  final Map<String, Object?> json;

  /// A concept that can't be read is left out, so one doesn't empty the list.
  ConceptBank toEntity() => ConceptBank(
    due: [
      for (final concept in json.readList('due') ?? const <Object?>[])
        ?_concept(asJsonMap(concept)),
    ],
    later: [
      for (final name in json.readList('later') ?? const <Object?>[])
        ?_name(asJsonMap(name)),
    ],
    mastered: [
      for (final name in json.readList('mastered') ?? const <Object?>[])
        ?_name(asJsonMap(name)),
    ],
  );

  static Concept? _concept(Map<String, Object?> json) {
    try {
      final id = _required(json.readString('id'));
      final wrong = json.readMap('wrong');
      final question = json.readMap('question');
      return Concept(
        id: id,
        arabic: _required(json.readString('ar')),
        english: _required(json.readString('en')),
        why: _required(json.readString('why')),
        example: [
          for (final part in json.readList('example') ?? const <Object?>[])
            RulePart(
              _required(asJsonMap(part).readString('text')),
              strong: asJsonMap(part).readBool('strong') ?? false,
            ),
        ],
        wrongAnswer: wrong?.readString('answer'),
        wrongFrom: wrong?.readString('lessonTitle'),
        stations: (json.readInt('stations') ?? 0).clamp(0, 4),
        repeats: json.readInt('repeats') ?? 1,
        lastRightAt: _date(json.readString('lastRightAt')),
        question: question == null
            ? null
            : exerciseFromJson(question, seed: id),
        explainEnabled: json.readBool('explainEnabled') ?? false,
      );
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'A concept skipped');
      return null;
    }
  }

  static ConceptName? _name(Map<String, Object?> json) {
    final id = json.readString('id');
    final arabic = json.readString('ar');
    if (id == null || arabic == null) return null;
    return ConceptName(
      id: id,
      arabic: arabic,
      english: json.readString('en'),
      dueAt: _date(json.readString('dueAt')),
    );
  }
}

/// One answer as it is sent: its id makes sending it twice harmless.
Map<String, Object?> conceptAnswerToJson({
  required String answerId,
  required String conceptId,
  required String? questionId,
  required bool correct,
  required DateTime at,
}) => {
  'answerId': answerId,
  'conceptId': conceptId,
  'questionId': ?questionId,
  'correct': correct,
  'answeredAt': at.toUtc().toIso8601String(),
};
