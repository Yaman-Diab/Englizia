import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:equatable/equatable.dart';

/// A pattern the learner got wrong, kept until it is mastered (S §11): never the
/// question itself, and never a count of mistakes.
final class Concept extends Equatable {
  const Concept({
    required this.id,
    required this.arabic,
    required this.english,
    required this.why,
    required this.stations,
    this.example = const [],
    this.wrongAnswer,
    this.wrongFrom,
    this.repeats = 1,
    this.lastRightAt,
    this.question,
    this.explainEnabled = false,
  });

  final String id;
  final String arabic;
  final String english;

  /// A short explanation, in Arabic.
  final String why;

  /// A right example, the part that matters strong.
  final List<RulePart> example;

  /// «أين أخطأت»: the learner's first answer that brought it here, and where.
  final String? wrongAnswer;
  final String? wrongFrom;

  /// How many of the five stations were passed: 0 to 4 while it is open.
  final int stations;

  /// «تكرر 3 مرات»: getting it wrong again raises it in the list.
  final int repeats;
  final DateTime? lastRightAt;

  /// Today's new question; with none, the concept is only shown.
  final Exercise? question;

  /// «اشرح لي» under a wrong answer, by the track's settings.
  final bool explainEnabled;

  @override
  List<Object?> get props => [
    id,
    arabic,
    english,
    why,
    example,
    wrongAnswer,
    wrongFrom,
    stations,
    repeats,
    lastRightAt,
    question,
    explainEnabled,
  ];
}

/// A concept, by its names only: one due later, or one mastered.
final class ConceptName extends Equatable {
  const ConceptName({
    required this.id,
    required this.arabic,
    this.english,
    this.dueAt,
  });

  final String id;
  final String arabic;
  final String? english;
  final DateTime? dueAt;

  @override
  List<Object?> get props => [id, arabic, english, dueAt];
}

/// «مفاهيم للتقوية»: those due today by priority, those coming, and those
/// mastered.
final class ConceptBank extends Equatable {
  const ConceptBank({
    this.due = const [],
    this.later = const [],
    this.mastered = const [],
  });

  final List<Concept> due;
  final List<ConceptName> later;
  final List<ConceptName> mastered;

  ConceptBank copyWith({
    List<Concept>? due,
    List<ConceptName>? later,
    List<ConceptName>? mastered,
  }) => ConceptBank(
    due: due ?? this.due,
    later: later ?? this.later,
    mastered: mastered ?? this.mastered,
  );

  @override
  List<Object?> get props => [due, later, mastered];
}
