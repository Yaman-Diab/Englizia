import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';

/// Where a lesson opens, by its kind: from home, a unit's timeline and a
/// lesson's «الدرس التالي» alike, so none of them opens a kind differently.
/// A kids' lesson opens its own screens; a conversation opens its «تحدّث»
/// scenario, or its exercises when it names none.
String lessonPath({
  required String id,
  required LessonKind kind,
  String? scenarioId,
  bool kids = false,
}) => switch (kind) {
  _ when kids => AppRoutes.kidsOf(id),
  LessonKind.vocabulary => AppRoutes.vocabularyOf(id),
  LessonKind.interactiveVideo => AppRoutes.videoOf(id),
  LessonKind.grammarVideo => AppRoutes.grammarOf(id),
  LessonKind.interactiveText => AppRoutes.textOf(id),
  LessonKind.conversation when scenarioId != null => AppRoutes.talkScenarioOf(
    scenarioId,
  ),
  _ => AppRoutes.exercisesOf(id),
};
