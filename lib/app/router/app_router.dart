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
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/account/domain/entities/password_link.dart';
import 'package:englizia/features/account/domain/entities/social_provider.dart';
import 'package:englizia/features/account/presentation/check_email/cubit/check_email_cubit.dart';
import 'package:englizia/features/account/presentation/check_email/pages/check_email_page.dart';
import 'package:englizia/features/account/presentation/forgot_password/cubit/forgot_password_cubit.dart';
import 'package:englizia/features/account/presentation/forgot_password/pages/forgot_password_page.dart';
import 'package:englizia/features/account/presentation/new_password/cubit/new_password_cubit.dart';
import 'package:englizia/features/account/presentation/new_password/pages/new_password_page.dart';
import 'package:englizia/features/account/presentation/password_changed/pages/password_changed_page.dart';
import 'package:englizia/features/account/presentation/password_changed/password_changed_args.dart';
import 'package:englizia/features/account/presentation/sign_in/cubit/sign_in_cubit.dart';
import 'package:englizia/features/account/presentation/sign_in/pages/sign_in_page.dart';
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
import 'package:englizia/features/onboarding/presentation/kid_welcome/cubit/kid_welcome_cubit.dart';
import 'package:englizia/features/onboarding/presentation/kid_welcome/pages/kid_welcome_page.dart';
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
import 'package:englizia/features/placement/presentation/intro/cubit/placement_intro_cubit.dart';
import 'package:englizia/features/placement/presentation/intro/pages/placement_intro_page.dart';
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

  // "Preparing" and the kids' welcome start the new account's session, and
  // the refresh that follows drops the route's `extra`; their arguments (a
  // session) stay here, in memory only, until the learner leaves.
  PreparingArgs? newAccount;

  PreparingArgs argsOf(GoRouterState state) =>
      newAccount = switch (state.extra) {
        final PreparingArgs args => args,
        _ => newAccount!,
      };
  String? withoutArgs(GoRouterState state) =>
      state.extra is PreparingArgs || newAccount != null
      ? null
      : AppRoutes.home;
  void leave(BuildContext context, String location, {Object? extra}) {
    newAccount = null;
    context.go(location, extra: extra);
  }

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
        redirect: (_, state) => withoutArgs(state),
        builder: (context, state) {
          final args = argsOf(state);
          return BlocProvider(
            create: (_) =>
                sl<PreparingCubit>()
                  ..start(path: args.path, account: args.session),
            child: PreparingPage(
              name: args.name,
              // ASSUMPTION(design): no lesson screen yet; home stands in.
              onStartLesson: () => leave(context, AppRoutes.home),
              onStartTest: () => leave(
                context,
                AppRoutes.onboardingPlacement,
                extra: args.path,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboardingKidWelcome,
        redirect: (_, state) => withoutArgs(state),
        builder: (context, state) {
          final args = argsOf(state);
          return BlocProvider(
            create: (_) => sl<KidWelcomeCubit>()..start(args.session),
            child: KidWelcomePage(
              childName: args.path.childName ?? '',
              // ASSUMPTION(design): no lesson screen yet; home stands in.
              onPlay: () => leave(context, AppRoutes.home),
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
        builder: (context, state) {
          final path = state.extra is OnboardingPath
              ? state.extra! as OnboardingPath
              : null;
          return BlocProvider(
            create: (_) =>
                sl<PlacementIntroCubit>()
                  ..start(path?.trackId, newAccount: path != null),
            child: PlacementIntroPage(
              // Preparing leaves nothing under this screen.
              onBack: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
              onStart: () => context.push(AppRoutes.placementQuestions),
              onSkip: () => context.go(AppRoutes.home),
              onLessons: () => context.go(AppRoutes.home),
            ),
          );
        },
      ),
      // The test's questions are not built yet.
      GoRoute(
        path: AppRoutes.placementQuestions,
        builder: (_, _) => PendingPage(title: 'placement_intro_title'.tr()),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) {
          // Sign-up hands over the email it was given, and so does "password
          // changed"; welcome hands none.
          final fromSignUp = state.extra is String;
          final settings = sl<SettingsStorageService>();
          return BlocProvider(
            create: (_) => sl<SignInCubit>(
              param1: switch (state.extra) {
                final String email => email,
                final PasswordChangedArgs args => args.email,
                _ => '',
              },
            ),
            child: SignInPage(
              lastProvider: SocialProvider.values
                  .asNameMap()[settings.lastSignInMethod],
              onSignedIn: (account) async {
                await session.signIn(account);
                // Pushed over home for a guest, which the guard leaves.
                if (context.mounted) context.go(AppRoutes.home);
              },
              onProvider: (_) => context.push(AppRoutes.signInWithProvider),
              onForgotPassword: (email) =>
                  context.push(AppRoutes.forgotPassword, extra: email),
              // Back to sign-up when it led here; else from the start of
              // onboarding, where accounts are made (S §4.3).
              onCreateAccount: () => fromSignUp
                  ? context.pop()
                  : context.push(AppRoutes.onboardingLanguage),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      // Google and Apple sign-in are not built yet.
      GoRoute(
        path: AppRoutes.signInWithProvider,
        builder: (_, _) => PendingPage(title: 'sign_in_title'.tr()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) {
          // Sign-in hands over its email; an expired link, the link's.
          final link = state.extra is PasswordLink
              ? state.extra! as PasswordLink
              : null;
          return BlocProvider(
            create: (_) => sl<ForgotPasswordCubit>(
              param1:
                  link?.email ??
                  (state.extra is String ? state.extra! as String : ''),
            ),
            child: ForgotPasswordPage(
              onSent: (email) =>
                  context.push(AppRoutes.forgotPasswordSent, extra: email),
              // Google is on sign-in: the screen before this one, unless a
              // link led here.
              onGoogle: () =>
                  link == null ? context.pop() : context.push(AppRoutes.signIn),
              onBack: () => context.pop(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPasswordSent,
        redirect: (_, state) =>
            state.extra is String ? null : AppRoutes.forgotPassword,
        builder: (context, state) => BlocProvider(
          create: (_) => sl<CheckEmailCubit>(param1: state.extra! as String),
          child: CheckEmailPage(onChange: () => context.pop()),
        ),
      ),
      GoRoute(
        path: AppRoutes.newPassword,
        builder: (context, state) {
          // The link in the email is the one way in, so this route alone
          // reads its arguments from the URL. A second link replaces the first.
          final query = state.uri.queryParameters;
          final link = PasswordLink(
            token: query['token'] ?? '',
            email: query['email'] ?? '',
          );
          return BlocProvider(
            key: ValueKey(link),
            create: (_) => sl<NewPasswordCubit>(param1: link)..verify(),
            child: NewPasswordPage(
              onClose: () => context.go(AppRoutes.home),
              onNewLink: () =>
                  context.push(AppRoutes.forgotPassword, extra: link),
              onSaved: (account) async {
                if (account != null) {
                  await session.signIn(account);
                } else if (session.status == SessionStatus.member) {
                  // The server closed this phone's session with the others;
                  // a guest's is another account, and stays.
                  await session.signOut();
                }
                if (context.mounted) {
                  context.go(
                    AppRoutes.passwordChanged,
                    extra: PasswordChangedArgs(
                      email: link.email,
                      signedIn: account != null,
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.passwordChanged,
        redirect: (_, state) =>
            state.extra is PasswordChangedArgs ? null : AppRoutes.home,
        builder: (context, state) {
          final args = state.extra! as PasswordChangedArgs;
          return PasswordChangedPage(
            signedIn: args.signedIn,
            onContinue: () => args.signedIn
                ? context.go(AppRoutes.home)
                : context.push(AppRoutes.signIn, extra: args),
            onLeave: () => context.go(AppRoutes.home),
          );
        },
      ),
    ],
  );
}

/// A new account goes on to "preparing", or on the child path to the kids'
/// welcome that replaces it (S §4.5); either starts its session. `go`
/// leaves the sign-up screens behind for good.
void _accountCreated(
  BuildContext context,
  OnboardingPath path,
  AuthTokens session, {
  String name = '',
}) => context.go(
  path.audience == TrackAudience.child
      ? AppRoutes.onboardingKidWelcome
      : AppRoutes.onboardingPreparing,
  extra: PreparingArgs(path: path, session: session, name: name),
);

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
