import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:equatable/equatable.dart';

/// Where a lesson left off: «توقفت عند السؤال 3».
final class LessonResume extends Equatable {
  const LessonResume({required this.question, required this.share});

  /// The question to carry on from, counting from 1.
  final int question;

  /// How much of the lesson is done, 0 to 1.
  final double share;

  @override
  List<Object?> get props => [question, share];
}

/// What the phone knows of a lesson that the server may not yet.
final class LessonOnPhone extends Equatable {
  const LessonOnPhone({this.kept = false, this.done = false, this.resume});

  /// It opens offline.
  final bool kept;

  /// Completed here, maybe still on its way to the server.
  final bool done;
  final LessonResume? resume;

  @override
  List<Object?> get props => [kept, done, resume];
}

/// One lesson in a unit's list (S §6.2).
final class UnitLesson extends Equatable {
  const UnitLesson({
    required this.id,
    required this.kind,
    required this.title,
    this.minutes,
    this.page,
    this.done = false,
    this.stars = 0,
    this.imageUrl,
    this.audioUrl,
    this.scenarioId,
    this.resume,
    this.kept = false,
  });

  final String id;
  final LessonKind kind;
  final String title;

  /// Its estimated length, from the panel.
  final int? minutes;

  /// Its page in the student's book (Emar).
  final int? page;
  final bool done;

  /// Kids: the stars it earned, out of five.
  final int stars;

  /// Kids: its card's picture, and its name said aloud.
  final String? imageUrl;
  final String? audioUrl;

  /// A conversation lesson is one of «تحدّث»'s scenarios.
  final String? scenarioId;
  final LessonResume? resume;

  /// It is kept on the phone, so it opens offline.
  final bool kept;

  bool get isReview => kind == LessonKind.unitReview;

  UnitLesson withPhone(LessonOnPhone phone) => UnitLesson(
    id: id,
    kind: kind,
    title: title,
    minutes: minutes,
    page: page,
    done: done || phone.done,
    stars: stars,
    imageUrl: imageUrl,
    audioUrl: audioUrl,
    scenarioId: scenarioId,
    // The phone knows its own place better; once done, nothing to resume.
    resume: done || phone.done ? null : phone.resume ?? resume,
    kept: phone.kept,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    title,
    minutes,
    page,
    done,
    stars,
    imageUrl,
    audioUrl,
    scenarioId,
    resume,
    kept,
  ];
}

/// Another unit this one points to: the one to finish first, or the next.
final class UnitLink extends Equatable {
  const UnitLink({required this.id, required this.number, this.title = ''});

  final String id;
  final int number;
  final String title;

  @override
  List<Object?> get props => [id, number, title];
}

enum UnitLessonStatus { done, current, open, locked }

/// A unit's screen (S §6.2, §13.5, §14): what it teaches, and its lessons in
/// the panel's order, however many there are.
final class UnitPlan extends Equatable {
  const UnitPlan({
    required this.id,
    required this.number,
    required this.title,
    required this.lessons,
    this.levelLabel = '',
    this.coverUrl,
    this.kids = false,
    this.ordered = true,
    this.goals = const [],
    this.concepts = const [],
    this.bookPages,
    this.titleAudioUrl,
    this.lockedBy,
    this.next,
  });

  final String id;
  final int number;
  final String title;
  final List<UnitLesson> lessons;

  /// The level's short name: «A2», «الصف 7», «Starter 2».
  final String levelLabel;
  final String? coverUrl;

  /// Kids mode: a grid of pictures, with no goals or grammar.
  final bool kids;

  /// Lessons open one after another; otherwise all are open and the first left
  /// is the one suggested (Emar).
  final bool ordered;

  /// «ستتعلّم أن…».
  final List<String> goals;

  /// «قواعد الوحدة»: the names of the concepts it targets.
  final List<String> concepts;

  /// The unit's pages in the student's book (Emar).
  final ({int from, int to})? bookPages;

  /// Kids: the unit's name, said by the guide.
  final String? titleAudioUrl;

  /// The unit is still locked: this one has to be finished first.
  final UnitLink? lockedBy;
  final UnitLink? next;

  bool get locked => lockedBy != null;

  int get doneCount => lessons.where((lesson) => lesson.done).length;

  bool get complete => lessons.isNotEmpty && lessons.every((l) => l.done);

  bool get _lessonsDone =>
      lessons.every((lesson) => lesson.done || lesson.isReview);

  /// The lesson to do now, or -1. The review waits for every other lesson.
  int get current {
    if (locked) return -1;
    for (final (index, lesson) in lessons.indexed) {
      if (lesson.done) continue;
      if (lesson.isReview && !_lessonsDone) continue;
      return index;
    }
    return -1;
  }

  UnitLessonStatus status(int index) {
    final lesson = lessons[index];
    if (lesson.done) return UnitLessonStatus.done;
    if (locked) return UnitLessonStatus.locked;
    if (index == current) return UnitLessonStatus.current;
    if (lesson.isReview && !_lessonsDone) return UnitLessonStatus.locked;
    return ordered ? UnitLessonStatus.locked : UnitLessonStatus.open;
  }

  UnitPlan withPhone(LessonOnPhone Function(String lessonId) phone) => UnitPlan(
    id: id,
    number: number,
    title: title,
    lessons: [for (final l in lessons) l.withPhone(phone(l.id))],
    levelLabel: levelLabel,
    coverUrl: coverUrl,
    kids: kids,
    ordered: ordered,
    goals: goals,
    concepts: concepts,
    bookPages: bookPages,
    titleAudioUrl: titleAudioUrl,
    lockedBy: lockedBy,
    next: next,
  );

  @override
  List<Object?> get props => [
    id,
    number,
    title,
    lessons,
    levelLabel,
    coverUrl,
    kids,
    ordered,
    goals,
    concepts,
    bookPages,
    titleAudioUrl,
    lockedBy,
    next,
  ];
}
