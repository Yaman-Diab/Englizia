import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/router/route_policies.dart';
import 'package:englizia/app/shell/foundation_page.dart';
import 'package:englizia/app/shell/pending_page.dart';
import 'package:englizia/app/shell/splash_page.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/presentation/sign_up/cubit/sign_up_cubit.dart';
import 'package:englizia/features/account/presentation/sign_up/pages/sign_up_page.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_cubit.dart';
import 'package:englizia/features/onboarding/presentation/audience/pages/audience_page.dart';
import 'package:englizia/features/onboarding/presentation/challenge/cubit/challenge_cubit.dart';
import 'package:englizia/features/onboarding/presentation/challenge/pages/challenge_page.dart';
import 'package:englizia/features/onboarding/presentation/child_profile/cubit/child_profile_cubit.dart';
import 'package:englizia/features/onboarding/presentation/child_profile/pages/child_profile_page.dart';
import 'package:englizia/features/onboarding/presentation/goal/cubit/goal_cubit.dart';
import 'package:englizia/features/onboarding/presentation/goal/pages/goal_page.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_cubit.dart';
import 'package:englizia/features/onboarding/presentation/grade/pages/grade_page.dart';
import 'package:englizia/features/onboarding/presentation/language/pages/language_page.dart';
import 'package:englizia/features/onboarding/presentation/level/cubit/level_cubit.dart';
import 'package:englizia/features/onboarding/presentation/level/pages/level_page.dart';
import 'package:englizia/features/onboarding/presentation/preparing/cubit/preparing_cubit.dart';
import 'package:englizia/features/onboarding/presentation/preparing/pages/preparing_page.dart';
import 'package:englizia/features/onboarding/presentation/preparing/preparing_args.dart';
import 'package:englizia/features/onboarding/presentation/reason/cubit/reason_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reason/pages/reason_page.dart';
import 'package:englizia/features/onboarding/presentation/reminder/cubit/reminder_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reminder/pages/reminder_page.dart';
import 'package:englizia/features/onboarding/presentation/save_progress/cubit/save_progress_cubit.dart';
import 'package:englizia/features/onboarding/presentation/save_progress/pages/save_progress_page.dart';
import 'package:englizia/features/onboarding/presentation/welcome/pages/welcome_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
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
    signedOutLocation: AppRoutes.welcome,
  );

  // "Preparing" starts the session, and the refresh that follows drops the
  // route's `extra`; its arguments (a session) stay here, in memory only,
  // until the learner leaves it.
  PreparingArgs? preparing;

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
              onContinue: (child) => _pushNextStep(
                context,
                OnboardingStep.childProfile,
                path.copyWith(
                  childName: child.name.trim(),
                  childAge: child.age,
                ),
              ),
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
              onContinue: (grade) => _pushNextStep(
                context,
                OnboardingStep.grade,
                path.copyWith(grade: grade),
              ),
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
              onContinue: (reasons) => _pushNextStep(
                context,
                OnboardingStep.reason,
                path.copyWith(reasons: reasons),
              ),
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
                path.copyWith(dailyGoalMinutes: minutes),
              ),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingChallenge,
        builder: (context, state) {
          final path = _pathOf(state);
          return BlocProvider(
            create: (_) =>
                sl<ChallengeCubit>()..load(chosen: path.challengeDays),
            child: ChallengePage(
              path: path,
              onContinue: (days) => _pushNextStep(
                context,
                OnboardingStep.challenge,
                path.copyWith(challengeDays: days),
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
          void next(TrackLevel? start) => _pushNextStep(
            context,
            OnboardingStep.level,
            path.copyWith(startLevel: start),
          );
          return BlocProvider(
            create: (_) => sl<LevelCubit>()..start(path.trackId),
            child: LevelPage(
              path: path,
              onStartFromBeginning: next,
              onTakeTest: () => _pushNextStep(
                context,
                OnboardingStep.level,
                path.copyWith(placementTest: true),
              ),
              onTestLater: next,
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingSaveProgress,
        builder: (context, state) {
          final path = _pathOf(state);
          return BlocProvider(
            create: (_) => sl<SaveProgressCubit>()..start(),
            child: SaveProgressPage(
              path: path,
              onCreateAccount: (provider) => context.push(
                provider == AccountProvider.email
                    ? AppRoutes.signUp
                    : AppRoutes.signUpWithProvider,
                extra: path,
              ),
              onTerms: () => context.push(AppRoutes.legalTerms),
              onPrivacy: () => context.push(AppRoutes.legalPrivacy),
              onGuestCreated: (session) =>
                  _accountCreated(context, path, session),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) {
          final path = _pathOf(state);
          // A guest signing up (from «أنا») upgrades the guest account and
          // goes straight back: the progress is already there.
          final upgrading = session.status == SessionStatus.guest;
          return BlocProvider(
            create: (_) => sl<SignUpCubit>(param1: upgrading),
            child: SignUpPage(
              onCreated: (account, name) async {
                if (!upgrading) {
                  return _accountCreated(context, path, account, name: name);
                }
                await session.signIn(account);
                // Pushed over home, which the guard leaves as it is.
                if (context.mounted) context.go(AppRoutes.home);
              },
              onSignIn: (email) => context.push(AppRoutes.signIn, extra: email),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingPreparing,
        redirect: (_, state) =>
            state.extra is PreparingArgs || preparing != null
            ? null
            : AppRoutes.home,
        builder: (context, state) {
          final args = preparing = switch (state.extra) {
            final PreparingArgs args => args,
            _ => preparing!,
          };
          void leave(String location, {Object? extra}) {
            preparing = null;
            context.go(location, extra: extra);
          }

          return BlocProvider(
            create: (_) =>
                sl<PreparingCubit>()
                  ..start(path: args.path, account: args.session),
            child: PreparingPage(
              name: args.name,
              // ASSUMPTION(design): no lesson screen yet; home stands in.
              onStartLesson: () => leave(AppRoutes.home),
              onStartTest: () =>
                  leave(AppRoutes.onboardingPlacement, extra: args.path),
            ),
          );
        },
      ),
      // Google and Apple sign-up are not built yet.
      GoRoute(
        path: AppRoutes.signUpWithProvider,
        builder: (_, _) => PendingPage(title: 'account_create_title'.tr()),
      ),
      GoRoute(
        path: AppRoutes.legalTerms,
        builder: (_, _) => PendingPage(title: 'onboarding_save_terms'.tr()),
      ),
      GoRoute(
        path: AppRoutes.legalPrivacy,
        builder: (_, _) => PendingPage(title: 'onboarding_save_privacy'.tr()),
      ),
      GoRoute(
        path: AppRoutes.onboardingReminder,
        builder: (context, state) {
          final path = _pathOf(state);
          return BlocProvider(
            create: (_) => sl<ReminderCubit>()..load(),
            child: ReminderPage(
              path: path,
              onContinue: (time) => _pushNextStep(
                context,
                OnboardingStep.reminder,
                path.copyWith(reminder: time),
              ),
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

/// A new account goes on to "preparing", which starts its session; `go`
/// leaves the sign-up screens behind for good. A child's account skips it
/// (the kids' welcome replaces it, S §4.5) and starts at once.
void _accountCreated(
  BuildContext context,
  OnboardingPath path,
  AuthTokens session, {
  String name = '',
}) {
  if (path.audience == TrackAudience.child) {
    sl<AppSessionController>().signIn(session);
    return;
  }
  context.go(
    AppRoutes.onboardingPreparing,
    extra: PreparingArgs(path: path, session: session, name: name),
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
  OnboardingStep.challenge => AppRoutes.onboardingChallenge,
  OnboardingStep.level => AppRoutes.onboardingLevel,
  OnboardingStep.reminder => AppRoutes.onboardingReminder,
  OnboardingStep.saveProgress => AppRoutes.onboardingSaveProgress,
};
