import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/router/route_policies.dart';
import 'package:englizia/app/shell/foundation_page.dart';
import 'package:englizia/app/shell/pending_page.dart';
import 'package:englizia/app/shell/splash_page.dart';
import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/onboarding/presentation/welcome/pages/welcome_page.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter(AppSessionController session) {
  final redirect = AppRedirect(
    status: () => session.status,
    policyFor: policyFor,
    splashLocation: AppRoutes.splash,
    homeLocation: AppRoutes.home,
    guestHomeLocation: AppRoutes.welcome,
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    debugLogDiagnostics: kDebugMode,
    redirect: redirect.call,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const FoundationPage()),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, _) => WelcomePage(
          onStart: () => context.push(AppRoutes.onboarding),
          onSignIn: () => context.push(AppRoutes.signIn),
        ),
      ),
      // Placeholders until the onboarding and account features exist.
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => PendingPage(title: 'welcome_start'.tr()),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, _) => PendingPage(title: 'welcome_have_account'.tr()),
      ),
    ],
  );
}
