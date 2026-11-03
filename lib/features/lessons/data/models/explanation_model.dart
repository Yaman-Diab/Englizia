import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/domain/entities/explanation.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/explanations.md).

String _required(String? value) =>
    value ?? (throw const FormatException('Explanation: a field is missing'));

/// The request of `POST /api/v1/app/explanations`.
Map<String, Object?> explainRequestToJson(ExplainRequest request) => {
  'questionId': request.questionId,
  'lessonId': ?request.lessonId,
  'conceptId': ?request.conceptId,
  'answer': answerToJson(request.draft),
};

/// Its answer: the explanation and the day's count, or none left today.
final class ExplainModel {
  const ExplainModel(this.json);

  final Map<String, Object?> json;

  ExplainOutcome toEntity() {
    if (json.readString('status') == 'quotaOut') return const ExplainQuotaOut();
    final explanation = json.readMap('explanation') ?? const {};
    final example = explanation.readMap('example') ?? const {};
    return ExplainReady(
      Explanation(
        id: _required(explanation.readString('id')),
        yours: _words(explanation.readList('yours'), 'wrong'),
        right: _words(explanation.readList('right'), 'fixed'),
        why: _required(explanation.readString('whyAr')),
        example: _required(example.readString('en')),
        exampleArabic: example.readString('ar') ?? '',
        exampleAudioUrl: example.readString('audioUrl'),
      ),
      left: json.readInt('left') ?? 0,
    );
  }

  static List<ExplainWord> _words(List<Object?>? json, String mark) => [
    for (final word in json ?? const <Object?>[])
      ExplainWord(
        _required(asJsonMap(word).readString('text')),
        marked: asJsonMap(word).readBool(mark) ?? false,
      ),
  ];
}
