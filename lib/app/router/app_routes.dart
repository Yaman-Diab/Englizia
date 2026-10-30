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
  static const onboardingPreparing = '/onboarding/preparing';
  static const onboardingKidWelcome = '/onboarding/kid-welcome';
  static const signIn = '/sign-in';
  static const signInWithProvider = '/sign-in/provider';
  static const forgotPassword = '/forgot-password';
  static const forgotPasswordSent = '/forgot-password/sent';

  /// The path of the link in a recovery email (docs/api/auth.md).
  static const newPassword = '/reset-password';
  static const passwordChanged = '/reset-password/done';
  static const signUp = '/sign-up';
  static const signUpWithProvider = '/sign-up/provider';
  static const legalTerms = '/legal/terms';
  static const legalPrivacy = '/legal/privacy';
}
