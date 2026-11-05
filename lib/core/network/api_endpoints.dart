/// Backend paths, one line each. Contract status lives in docs/api/.
abstract final class ApiEndpoints {
  // Confirmed in docs/api/openapi.json.
  static const refreshToken = '/api/v1/auth/refresh';
  // Confirmed in docs/api/openapi.json.
  static const register = '/api/v1/auth/register';
  // Confirmed in docs/api/openapi.json.
  static const login = '/api/v1/auth/login';
  // Confirmed in docs/api/openapi.json.
  static const logout = '/api/v1/auth/logout';
  // ASSUMPTION(api): docs/api/auth.md.
  static const guestAccount = '/api/v1/auth/guest';
  // ASSUMPTION(api): docs/api/auth.md.
  static const upgradeGuest = '/api/v1/auth/guest/upgrade';
  // ASSUMPTION(api): docs/api/auth.md.
  static const forgotPassword = '/api/v1/auth/password/forgot';
  // ASSUMPTION(api): docs/api/auth.md.
  static const verifyPasswordLink = '/api/v1/auth/password/reset/verify';
  // ASSUMPTION(api): docs/api/auth.md.
  static const resetPassword = '/api/v1/auth/password/reset';

  // Confirmed in docs/api/openapi.json.
  static const me = '/api/v1/app/me';

  // ASSUMPTION(api): proposed, docs/api/me.md.
  static const profile = '/api/v1/app/me/profile';

  // ASSUMPTION(api): proposed, docs/api/me.md.
  static const activeEnrollment = '/api/v1/app/me/active-enrollment';

  // ASSUMPTION(api): proposed, docs/api/home.md.
  static const home = '/api/v1/app/home';

  // ASSUMPTION(api): proposed, docs/api/me.md.
  static const preferences = '/api/v1/app/me/preferences';

  // ASSUMPTION(api): proposed, docs/api/me.md.
  static const changePassword = '/api/v1/auth/password/change';
  // ASSUMPTION(api): docs/api/auth.md.
  static const emailResend = '/api/v1/auth/email/resend';
  // ASSUMPTION(api): docs/api/auth.md.
  static const emailChange = '/api/v1/auth/email';
  // ASSUMPTION(api): docs/api/auth.md.
  static const emailVerify = '/api/v1/auth/email/verify';

  // ASSUMPTION(api): docs/api/tracks.md.
  static const tracks = '/api/v1/app/tracks';
  // ASSUMPTION(api): docs/api/placement.md.
  static const placementSummary = '/api/v1/app/placement/summary';
  // ASSUMPTION(api): docs/api/placement.md.
  static const placementStatus = '/api/v1/app/placement/status';
  // ASSUMPTION(api): docs/api/placement.md.
  static const placementAttempts = '/api/v1/app/placement/attempts';
  // ASSUMPTION(api): docs/api/settings.md.
  static const settings = '/api/v1/app/settings';

  // ASSUMPTION(api): docs/api/placement.md.
  static String placementStage(String attemptId, int stage) =>
      '/api/v1/app/placement/attempts/$attemptId/stages/$stage';

  // ASSUMPTION(api): docs/api/placement.md.
  static String placementAnswers(String attemptId) =>
      '/api/v1/app/placement/attempts/$attemptId/answers';

  // ASSUMPTION(api): docs/api/placement.md.
  static String placementStageComplete(String attemptId, int stage) =>
      '/api/v1/app/placement/attempts/$attemptId/stages/$stage/complete';

  // ASSUMPTION(api): docs/api/placement.md.
  static String placementResult(String attemptId) =>
      '/api/v1/app/placement/attempts/$attemptId/result';

  // ASSUMPTION(api): docs/api/placement.md.
  static String placementAccept(String attemptId) =>
      '/api/v1/app/placement/attempts/$attemptId/accept';

  // ASSUMPTION(api): docs/api/placement.md.
  static String enrollment(String enrollmentId) =>
      '/api/v1/app/enrollments/$enrollmentId';

  // ASSUMPTION(api): docs/api/lessons.md.
  static String unit(String unitId) => '/api/v1/app/units/$unitId';

  static String lesson(String lessonId) => '/api/v1/app/lessons/$lessonId';

  // ASSUMPTION(api): docs/api/lessons.md.
  static String lessonAnswerReview(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/answers/review';

  static String lessonWords(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/words';

  static String lessonContentDone(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/content-done';

  static String lessonShadowing(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/shadowing';

  // ASSUMPTION(api): docs/api/practice.md.
  static const wordBank = '/api/v1/app/word-bank';

  static const wordBankReviews = '/api/v1/app/word-bank/reviews';

  static String wordBankWord(String wordId) =>
      '/api/v1/app/word-bank/words/$wordId';

  // ASSUMPTION(api): docs/api/concepts.md.
  static const concepts = '/api/v1/app/concepts';

  static const conceptAnswers = '/api/v1/app/concepts/answers';

  static const conceptReports = '/api/v1/app/concepts/reports';

  // ASSUMPTION(api): docs/api/explanations.md.
  static const explanations = '/api/v1/app/explanations';

  static String explanationRating(String explanationId) =>
      '/api/v1/app/explanations/$explanationId/rating';

  // ASSUMPTION(api): docs/api/talk.md.
  static const talk = '/api/v1/app/talk';

  static String talkScenario(String scenarioId) =>
      '/api/v1/app/talk/scenarios/$scenarioId';

  static const talkConversations = '/api/v1/app/talk/conversations';

  static String talkTurns(String conversationId) =>
      '/api/v1/app/talk/conversations/$conversationId/turns';

  static String talkEnd(String conversationId) =>
      '/api/v1/app/talk/conversations/$conversationId/end';

  static String talkNotes(String conversationId) =>
      '/api/v1/app/talk/conversations/$conversationId/notes';

  static String lessonWatch(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/watch';

  static String lessonQuestions(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/questions';

  static String lessonCompletion(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/complete';

  static String lessonSpokenReview(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/answers/spoken-review';

  // ASSUMPTION(api): docs/api/lessons.md.
  static String lessonReports(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/reports';

  // ASSUMPTION(api): docs/api/lessons.md.
  static String lessonAnswers(String lessonId) =>
      '/api/v1/app/lessons/$lessonId/answers';

  // ASSUMPTION(api): docs/api/tracks.md.
  static String levelUnits(String levelId) =>
      '/api/v1/app/levels/$levelId/units';

  static String trackLevels(String trackId) =>
      '/api/v1/app/tracks/$trackId/levels';
}
