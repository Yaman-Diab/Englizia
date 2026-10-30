import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/core/router/route_policy.dart';

/// Route pattern → access policy. The single source of truth for access
/// control; buttons may only mirror it. Unlisted routes need a guest or
/// member session.
const routePolicies = <String, RoutePolicy>{
  AppRoutes.splash: RoutePolicy.public,
  AppRoutes.welcome: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingLanguage: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingAudience: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingChildProfile: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingGrade: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingReason: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingGoal: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingChallenge: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingLevel: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingReminder: RoutePolicy.signedOutOnly,
  AppRoutes.onboardingSaveProgress: RoutePolicy.signedOutOnly,
  // Starts the session itself, so it must stay open when the session does.
  AppRoutes.onboardingPreparing: RoutePolicy.public,
  AppRoutes.onboardingKidWelcome: RoutePolicy.public,
  AppRoutes.signIn: RoutePolicy.withoutAccount,
  AppRoutes.signInWithProvider: RoutePolicy.withoutAccount,
  // A recovery link can open these on a phone that is signed in.
  AppRoutes.forgotPassword: RoutePolicy.public,
  AppRoutes.forgotPasswordSent: RoutePolicy.public,
  AppRoutes.newPassword: RoutePolicy.public,
  AppRoutes.passwordChanged: RoutePolicy.public,
  // A link can open it on a phone signed out, or signed in as anyone.
  AppRoutes.verifyEmail: RoutePolicy.public,
  AppRoutes.signUp: RoutePolicy.withoutAccount,
  AppRoutes.signUpWithProvider: RoutePolicy.withoutAccount,
  AppRoutes.legalTerms: RoutePolicy.public,
  AppRoutes.legalPrivacy: RoutePolicy.public,
};

RoutePolicy policyFor(String routePattern) =>
    routePolicies[routePattern] ?? RoutePolicy.requiresSession;
