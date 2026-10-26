import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/core/router/route_policy.dart';

/// Route pattern → access policy. The single source of truth for access
/// control; buttons may only mirror it. Unlisted routes require login.
const routePolicies = <String, RoutePolicy>{
  AppRoutes.splash: RoutePolicy.public,
  AppRoutes.welcome: RoutePolicy.guestOnly,
  AppRoutes.onboardingLanguage: RoutePolicy.guestOnly,
  AppRoutes.onboardingAudience: RoutePolicy.guestOnly,
  AppRoutes.signIn: RoutePolicy.guestOnly,
};

RoutePolicy policyFor(String routePattern) =>
    routePolicies[routePattern] ?? RoutePolicy.requiresLogin;
