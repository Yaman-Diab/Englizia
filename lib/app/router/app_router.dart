import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/router/route_policies.dart';
import 'package:englizia/app/shell/foundation_page.dart';
import 'package:englizia/app/shell/splash_page.dart';
import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter(AppSessionController session) {
  final redirect = AppRedirect(
    status: () => session.status,
    policyFor: policyFor,
    splashLocation: AppRoutes.splash,
    homeLocation: AppRoutes.home,
    // Points at the login route once the auth feature adds it.
    loginLocation: AppRoutes.home,
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    debugLogDiagnostics: kDebugMode,
    redirect: redirect.call,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const FoundationPage()),
    ],
  );
}
