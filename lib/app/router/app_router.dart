import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/router/route_policies.dart';
import 'package:englizia/app/shell/foundation_page.dart';
import 'package:englizia/app/shell/pending_page.dart';
import 'package:englizia/app/shell/splash_page.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_cubit.dart';
import 'package:englizia/features/onboarding/presentation/audience/pages/audience_page.dart';
import 'package:englizia/features/onboarding/presentation/child_profile/cubit/child_profile_cubit.dart';
import 'package:englizia/features/onboarding/presentation/child_profile/pages/child_profile_page.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_cubit.dart';
import 'package:englizia/features/onboarding/presentation/grade/pages/grade_page.dart';
import 'package:englizia/features/onboarding/presentation/language/pages/language_page.dart';
import 'package:englizia/features/onboarding/presentation/welcome/pages/welcome_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
          onStart: () => context.push(AppRoutes.onboardingLanguage),
          onSignIn: () => context.push(AppRoutes.signIn),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingLanguage,
        builder: (context, _) => LanguagePage(
          onContinue: () => context.push(AppRoutes.onboardingAudience),
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.welcome),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingAudience,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<AudienceCubit>()..load(),
          child: AudiencePage(
            onContinue: (audience) {
              final next = onboardingNextStep(
                OnboardingStep.audience,
                audience: audience,
              );
              if (next != null) context.push(_onboardingRoute(next));
            },
            onBack: () => context.pop(),
          ),
        ),
      ),
      // Placeholders until the next onboarding steps and sign-in exist.
      GoRoute(
        path: AppRoutes.onboardingChildProfile,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<ChildProfileCubit>(),
          child: ChildProfilePage(
            onContinue: (_) => context.push(
              _onboardingRoute(
                onboardingNextStep(
                  OnboardingStep.childProfile,
                  audience: TrackAudience.child,
                )!,
              ),
            ),
            onBack: () => context.pop(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingGrade,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<GradeCubit>()..load(),
          child: GradePage(
            onContinue: (_) => context.push(
              _onboardingRoute(
                onboardingNextStep(
                  OnboardingStep.grade,
                  audience: TrackAudience.schoolStudent,
                )!,
              ),
            ),
            onBack: () => context.pop(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingReason,
        builder: (_, _) =>
            PendingPage(title: 'onboarding_reason_question'.tr()),
      ),
      GoRoute(
        path: AppRoutes.onboardingSaveProgress,
        builder: (_, _) => PendingPage(title: 'onboarding_save_title'.tr()),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, _) => PendingPage(title: 'welcome_have_account'.tr()),
      ),
    ],
  );
}

String _onboardingRoute(OnboardingStep step) => switch (step) {
  OnboardingStep.language => AppRoutes.onboardingLanguage,
  OnboardingStep.audience => AppRoutes.onboardingAudience,
  OnboardingStep.childProfile => AppRoutes.onboardingChildProfile,
  OnboardingStep.grade => AppRoutes.onboardingGrade,
  OnboardingStep.reason => AppRoutes.onboardingReason,
  OnboardingStep.saveProgress => AppRoutes.onboardingSaveProgress,
};
