/// Route paths: kebab-case, sub-screens nested under their parent.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const home = '/';
  static const welcome = '/welcome';
  static const onboardingLanguage = '/onboarding/language';
  static const onboardingAudience = '/onboarding/audience';
  static const onboardingChildProfile = '/onboarding/child-profile';
  static const onboardingGrade = '/onboarding/grade';
  static const onboardingReason = '/onboarding/reason';
  static const onboardingGoal = '/onboarding/goal';
  static const onboardingChallenge = '/onboarding/challenge';
  static const onboardingLevel = '/onboarding/level';
  static const onboardingReminder = '/onboarding/reminder';
  static const onboardingSaveProgress = '/onboarding/save-progress';
  static const onboardingPlacement = '/onboarding/placement-test';
  static const placementQuestions = '/onboarding/placement-test/questions';
  static const placementResult = '/onboarding/placement-test/result';
  static const onboardingPreparing = '/onboarding/preparing';
  static const onboardingKidWelcome = '/onboarding/kid-welcome';
  static const signIn = '/sign-in';
  static const signInWithProvider = '/sign-in/provider';
  static const forgotPassword = '/forgot-password';
  static const forgotPasswordSent = '/forgot-password/sent';

  /// The path of the link in a recovery email (docs/api/auth.md).
  static const newPassword = '/reset-password';
  static const passwordChanged = '/reset-password/done';

  static const lessonGrammar = '/lessons/:lessonId/grammar';
  static const lessonText = '/lessons/:lessonId/text';
  static const lessonVideo = '/lessons/:lessonId/video';
  static const lessonVocabulary = '/lessons/:lessonId/vocabulary';
  static const lessonShadowing = '/lessons/:lessonId/shadowing';
  static const lessonExercises = '/lessons/:lessonId/exercises';
  static const lessonComplete = '/lessons/:lessonId/complete';
  static const lessonExplain = '/lessons/:lessonId/explain';

  /// Screens a lesson's end leads to, not built yet.
  static const savedWords = '/words';
  static const practice = '/practice';
  static const practiceReview = '/practice/review';
  static const practiceConcepts = '/practice/concepts';
  static const practiceConceptSession = '/practice/concepts/session';
  static const conceptExplain = '/practice/concepts/explain';
  static const practiceSentences = '/practice/sentences';
  static const talk = '/talk';
  static const me = '/me';
  static const unitStart = '/units/next';

  static String grammarOf(String lessonId) => '/lessons/$lessonId/grammar';

  static String textOf(String lessonId) => '/lessons/$lessonId/text';

  static String videoOf(String lessonId) => '/lessons/$lessonId/video';

  static String vocabularyOf(String lessonId) =>
      '/lessons/$lessonId/vocabulary';

  static String shadowingOf(String lessonId) => '/lessons/$lessonId/shadowing';

  static String exercisesOf(String lessonId) => '/lessons/$lessonId/exercises';

  static String completeOf(String lessonId) => '/lessons/$lessonId/complete';

  static String explainOf(String lessonId) => '/lessons/$lessonId/explain';

  /// The path of the link that confirms an email (docs/api/auth.md).
  static const verifyEmail = '/verify-email';
  static const signUp = '/sign-up';
  static const signUpWithProvider = '/sign-up/provider';
  static const legalTerms = '/legal/terms';
  static const legalPrivacy = '/legal/privacy';
}
