import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/teacher_question_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/grammar_model.dart';
import 'package:englizia/features/lessons/domain/entities/teacher_question.dart';
import 'package:englizia/features/lessons/domain/repositories/teacher_question_repository.dart';

final class TeacherQuestionRepositoryImpl implements TeacherQuestionRepository {
  const TeacherQuestionRepositoryImpl(this._remote);

  final TeacherQuestionRemoteDataSource _remote;

  @override
  Future<Result<List<TeacherQuestion>>> list(String lessonId) =>
      guard(() => _remote.list(lessonId));

  @override
  String newQuestionId() => SettingsStorageService.randomId();

  @override
  Future<Result<TeacherQuestion>> ask(
    String lessonId,
    TeacherQuestion question,
  ) => guard(() => _remote.ask(lessonId, questionToJson(question)));
}
