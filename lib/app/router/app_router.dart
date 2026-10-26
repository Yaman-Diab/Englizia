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
import 'package:englizia/features/onboarding/presentation/goal/cubit/goal_cubit.dart';
import 'package:englizia/features/onboarding/presentation/goal/pages/goal_page.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_cubit.dart';
import 'package:englizia/features/onboarding/presentation/grade/pages/grade_page.dart';
import 'package:englizia/features/onboarding/presentation/language/pages/language_page.dart';
import 'package:englizia/features/onboarding/presentation/level/cubit/level_cubit.dart';
import 'package:englizia/features/onboarding/presentation/level/pages/level_page.dart';
import 'package:englizia/features/onboarding/presentation/reason/cubit/reason_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reason/pages/reason_page.dart';
import 'package:englizia/features/onboarding/presentation/reminder/cubit/reminder_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reminder/pages/reminder_page.dart';
import 'package:englizia/features/onboarding/presentation/welcome/pages/welcome_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
            onContinue: (path) =>
                _pushNextStep(context, OnboardingStep.audience, path),
            onBack: () => context.pop(),
          ),
        ),
      ),
      // Placeholders until the next onboarding steps and sign-in exist.
      GoRoute(
        path: AppRoutes.onboardingChildProfile,
        builder: (context, state) {
          final path = _pathOf(state);
          return BlocProvider(
            create: (_) => sl<ChildProfileCubit>(),
            child: ChildProfilePage(
              path: path,
              onContinue: (_) =>
                  _pushNextStep(context, OnboardingStep.childProfile, path),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingGrade,
        builder: (context, state) {
          final path = _pathOf(state);
          return BlocProvider(
            create: (_) => sl<GradeCubit>()..load(),
            child: GradePage(
              path: path,
              onContinue: (_) =>
                  _pushNextStep(context, OnboardingStep.grade, path),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingReason,
        builder: (context, state) {
          final path = _pathOf(state);
          return BlocProvider(
            create: (_) => sl<ReasonCubit>(),
            child: ReasonPage(
              path: path,
              onContinue: (_) =>
                  _pushNextStep(context, OnboardingStep.reason, path),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingGoal,
        builder: (context, state) {
          final path = _pathOf(state);
          return BlocProvider(
            create: (_) => sl<GoalCubit>()..load(chosen: path.dailyGoalMinutes),
            child: GoalPage(
              path: path,
              onContinue: (minutes) => _pushNextStep(
                context,
                OnboardingStep.goal,
                path.withDailyGoal(minutes),
              ),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingLevel,
        builder: (context, state) {
          final path = _pathOf(state);
          void next() => _pushNextStep(context, OnboardingStep.level, path);
          return BlocProvider(
            create: (_) => sl<LevelCubit>()..start(path.trackId),
            child: LevelPage(
              path: path,
              onStartFromBeginning: next,
              onTakeTest: () =>
                  context.push(AppRoutes.onboardingPlacement, extra: path),
              onTestLater: next,
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingSaveProgress,
        builder: (_, _) => PendingPage(title: 'onboarding_save_title'.tr()),
      ),
      GoRoute(
        path: AppRoutes.onboardingReminder,
        builder: (context, state) {
          final path = _pathOf(state);
          return BlocProvider(
            create: (_) => sl<ReminderCubit>()..load(),
            child: ReminderPage(
              path: path,
              onContinue: (_) =>
                  _pushNextStep(context, OnboardingStep.reminder, path),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingPlacement,
        builder: (_, _) => PendingPage(title: 'placement_intro_title'.tr()),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, _) => PendingPage(title: 'welcome_have_account'.tr()),
      ),
    ],
  );
}

/// Opens the step after [from] on the learner's path, if there is one,
/// handing the path on.
void _pushNextStep(
  BuildContext context,
  OnboardingStep from,
  OnboardingPath path,
) {
  final next = onboardingNextStep(from, path: path);
  if (next != null) context.push(_onboardingRoute(next), extra: path);
}

/// The learner's path travels between steps as route `extra`; a step opened
/// without it (deep link, restored route) assumes the common adult path.
OnboardingPath _pathOf(GoRouterState state) => switch (state.extra) {
  final OnboardingPath path => path,
  _ => OnboardingPath.assumed,
};

String _onboardingRoute(OnboardingStep step) => switch (step) {
  OnboardingStep.language => AppRoutes.onboardingLanguage,
  OnboardingStep.audience => AppRoutes.onboardingAudience,
  OnboardingStep.childProfile => AppRoutes.onboardingChildProfile,
  OnboardingStep.grade => AppRoutes.onboardingGrade,
  OnboardingStep.reason => AppRoutes.onboardingReason,
  OnboardingStep.goal => AppRoutes.onboardingGoal,
  OnboardingStep.level => AppRoutes.onboardingLevel,
  OnboardingStep.reminder => AppRoutes.onboardingReminder,
  OnboardingStep.saveProgress => AppRoutes.onboardingSaveProgress,
};
