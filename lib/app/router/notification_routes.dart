import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/core/notifications/push_message.dart';

/// Asks home to open the next lesson (a reminder's tap); each one is new.
final class OpenNextLesson {
  OpenNextLesson();
}

/// Asks a grammar lesson to open its questions (a teacher's reply).
final class OpenQuestions {
  const OpenQuestions();
}

/// Where a tapped notification leads (design "Notifications" 11), once the
/// opening is done and an account is on the phone. A reply opens its
/// lesson's questions; a reminder, the next lesson from home. What can't be
/// found ends on home, which the redirect turns into a child's own.
({String location, Object? extra, bool push}) notificationDestination(
  PushMessage message,
) => switch (message) {
  PushMessage(kind: PushKind.teacherReply, :final lessonId?) => (
    location: AppRoutes.grammarOf(lessonId),
    extra: const OpenQuestions(),
    push: true,
  ),
  PushMessage(kind: PushKind.dailyGoal || PushKind.streak) => (
    location: AppRoutes.home,
    extra: OpenNextLesson(),
    push: false,
  ),
  _ => (location: AppRoutes.home, extra: null, push: false),
};

/// The learner is learning at [path]: a lesson, a test, the microphone,
/// onboarding, or the reminders' prompt. No banner then (design 05).
bool isLearningPath(String path) =>
    path.startsWith('/lessons/') ||
    path.startsWith('/onboarding') ||
    path.startsWith('/talk/scenarios/') ||
    path == AppRoutes.practiceReview ||
    path == AppRoutes.practiceConceptSession ||
    path == AppRoutes.kidsReview ||
    path == AppRoutes.notificationPrompt;
