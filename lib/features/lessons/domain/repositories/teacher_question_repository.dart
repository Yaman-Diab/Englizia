import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/teacher_question.dart';

abstract interface class TeacherQuestionRepository {
  /// The learner's own questions on this lesson, newest first. The server sends
  /// no one else's (ADR 14).
  Future<Result<List<TeacherQuestion>>> list(String lessonId);

  /// A new id for a question about to be asked.
  String newQuestionId();

  /// Safe to repeat under the same [TeacherQuestion.id].
  Future<Result<TeacherQuestion>> ask(
    String lessonId,
    TeacherQuestion question,
  );
}
