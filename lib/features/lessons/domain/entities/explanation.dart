import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:equatable/equatable.dart';

/// What «اشرح لي» asks about: a question, and the learner's wrong answer.
final class ExplainRequest extends Equatable {
  const ExplainRequest({
    required this.questionId,
    required this.draft,
    this.lessonId,
    this.conceptId,
    this.lessonExplanation,
  });

  final String questionId;
  final ExerciseDraft draft;

  /// Where the question comes from: a lesson, or a concept to strengthen.
  final String? lessonId;
  final String? conceptId;

  /// The lesson's own explanation, shown when the AI's can't be.
  final String? lessonExplanation;

  @override
  List<Object?> get props => [
    questionId,
    draft,
    lessonId,
    conceptId,
    lessonExplanation,
  ];
}

/// A word of a sentence in the explanation: in the learner's answer, [marked]
/// is a word that was wrong; in the right one, a word that was put right.
final class ExplainWord extends Equatable {
  const ExplainWord(this.text, {this.marked = false});

  final String text;
  final bool marked;

  @override
  List<Object?> get props => [text, marked];
}

/// The AI's explanation of this learner's mistake (requirements v3.0 §7.2,
/// design "Explain Me"), made and checked by the server.
final class Explanation extends Equatable {
  const Explanation({
    required this.id,
    required this.why,
    required this.example,
    required this.exampleArabic,
    this.yours = const [],
    this.right = const [],
    this.exampleAudioUrl,
  });

  final String id;

  /// «إجابتك» and «الصحيح»; empty where a template has no sentence to show.
  final List<ExplainWord> yours;
  final List<ExplainWord> right;

  /// «السبب», in Arabic: three sentences at most.
  final String why;

  /// «مثال آخر», with its translation and voice.
  final String example;
  final String exampleArabic;
  final String? exampleAudioUrl;

  @override
  List<Object?> get props => [
    id,
    yours,
    right,
    why,
    example,
    exampleArabic,
    exampleAudioUrl,
  ];
}

/// What asking for an explanation came to.
sealed class ExplainOutcome extends Equatable {
  const ExplainOutcome();
}

/// The explanation, and the explanations left today when known. [fresh] is
/// false when it was already on the phone: shown at once, and nothing counted.
final class ExplainReady extends ExplainOutcome {
  const ExplainReady(this.explanation, {required this.left, this.fresh = true});

  final Explanation explanation;
  final int? left;
  final bool fresh;

  @override
  List<Object?> get props => [explanation, left, fresh];
}

/// Today's explanations are used up; the AI isn't asked.
final class ExplainQuotaOut extends ExplainOutcome {
  const ExplainQuotaOut();

  @override
  List<Object?> get props => [];
}
