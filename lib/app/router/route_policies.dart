import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/core/router/route_policy.dart';

/// Route pattern → access policy. The single source of truth for access
/// control; buttons may only mirror it. Unlisted routes require login.
const routePolicies = <String, RoutePolicy>{
  AppRoutes.splash: RoutePolicy.public,
  AppRoutes.welcome: RoutePolicy.guestOnly,
  AppRoutes.onboardingLanguage: RoutePolicy.guestOnly,
  AppRoutes.onboardingAudience: RoutePolicy.guestOnly,
  AppRoutes.onboardingChildProfile: RoutePolicy.guestOnly,
  AppRoutes.onboardingGrade: RoutePolicy.guestOnly,
  AppRoutes.onboardingReason: RoutePolicy.guestOnly,
  AppRoutes.onboardingLevel: RoutePolicy.guestOnly,
  AppRoutes.onboardingReminder: RoutePolicy.guestOnly,
  AppRoutes.onboardingSaveProgress: RoutePolicy.guestOnly,
  AppRoutes.onboardingPlacement: RoutePolicy.guestOnly,
  AppRoutes.signIn: RoutePolicy.guestOnly,
};

RoutePolicy policyFor(String routePattern) =>
    routePolicies[routePattern] ?? RoutePolicy.requiresLogin;
