import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/router/lesson_paths.dart';
import 'package:englizia/app/router/route_policies.dart';
import 'package:englizia/app/shell/foundation_page.dart';
import 'package:englizia/app/shell/kid_tab_shell.dart';
import 'package:englizia/app/shell/pending_page.dart';
import 'package:englizia/app/shell/tab_shell.dart';
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/config/app_info.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/links/external_link.dart';
import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/account/domain/entities/password_link.dart';
import 'package:englizia/features/account/domain/entities/social_provider.dart';
import 'package:englizia/features/account/presentation/account/cubit/account_cubit.dart';
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
import 'package:englizia/features/account/presentation/verify_email/cubit/email_link_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/verify_email_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/pages/email_link_page.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_host.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_sheet.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/home/presentation/home/pages/home_page.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_cubit.dart';
import 'package:englizia/features/launch/presentation/splash/pages/splash_page.dart';
import 'package:englizia/features/launch/presentation/update_reminder/update_reminder.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/lessons/presentation/complete/cubit/lesson_complete_cubit.dart';
import 'package:englizia/features/lessons/presentation/complete/pages/lesson_complete_page.dart';
import 'package:englizia/features/lessons/presentation/concepts/cubit/concept_session_cubit.dart';
import 'package:englizia/features/lessons/presentation/concepts/cubit/concepts_cubit.dart';
import 'package:englizia/features/lessons/presentation/concepts/pages/concept_session_page.dart';
import 'package:englizia/features/lessons/presentation/concepts/pages/concepts_page.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/pages/exercise_page.dart';
import 'package:englizia/features/lessons/presentation/explain/cubit/explain_cubit.dart';
import 'package:englizia/features/lessons/presentation/explain/widgets/explain_sheet.dart';
import 'package:englizia/features/lessons/presentation/grammar/cubit/grammar_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/grammar/cubit/teacher_questions_cubit.dart';
import 'package:englizia/features/lessons/presentation/grammar/pages/grammar_lesson_page.dart';
import 'package:englizia/features/lessons/presentation/kids/cubit/kid_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/kids/pages/kid_lesson_page.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/interactive_text_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/interactive_video_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/pages/interactive_text_page.dart';
import 'package:englizia/features/lessons/presentation/reader/pages/interactive_video_page.dart';
import 'package:englizia/features/lessons/presentation/shadowing/cubit/shadowing_cubit.dart';
import 'package:englizia/features/lessons/presentation/shadowing/pages/shadowing_page.dart';
import 'package:englizia/features/lessons/presentation/unit/cubit/unit_cubit.dart';
import 'package:englizia/features/lessons/presentation/unit/pages/unit_page.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/cubit/vocab_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/pages/vocab_lesson_page.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:englizia/features/me/presentation/me/pages/me_page.dart';
import 'package:englizia/features/me/presentation/settings/cubit/preferences_cubit.dart';
import 'package:englizia/features/me/presentation/settings/pages/account_pages.dart';
import 'package:englizia/features/me/presentation/settings/pages/settings_page.dart';
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
import 'package:englizia/features/placement/presentation/result/cubit/placement_result_cubit.dart';
import 'package:englizia/features/placement/presentation/result/pages/placement_result_page.dart';
import 'package:englizia/features/placement/presentation/test/cubit/placement_test_cubit.dart';
import 'package:englizia/features/placement/presentation/test/pages/placement_test_page.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/repositories/practice_repository.dart';
import 'package:englizia/features/practice/presentation/kids/cubit/kid_words_cubit.dart';
import 'package:englizia/features/practice/presentation/kids/pages/kid_review_page.dart';
import 'package:englizia/features/practice/presentation/kids/pages/kid_words_page.dart';
import 'package:englizia/features/practice/presentation/practice/cubit/practice_cubit.dart';
import 'package:englizia/features/practice/presentation/practice/pages/practice_page.dart';
import 'package:englizia/features/practice/presentation/review/cubit/review_cubit.dart';
import 'package:englizia/features/practice/presentation/review/pages/review_page.dart';
import 'package:englizia/features/practice/presentation/words/cubit/my_words_cubit.dart';
import 'package:englizia/features/practice/presentation/words/pages/my_words_page.dart';
import 'package:englizia/features/talk/presentation/conversation/cubit/conversation_cubit.dart';
import 'package:englizia/features/talk/presentation/conversation/pages/conversation_page.dart';
import 'package:englizia/features/talk/presentation/talk/cubit/talk_cubit.dart';
import 'package:englizia/features/talk/presentation/talk/pages/talk_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter(
  AppSessionController session, {
  required SplashCubit launch,
}) {
  final redirect = AppRedirect(
    status: () => session.status,
    launch: () => launch.state.launch,
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

  // Tells home when a page covers it and closes again (a return).
  final pages = RouteObserver<PageRoute<dynamic>>();

  // The dev page's last restart of home: a later way there without one
  // keeps the home it started.
  HomeRestart? homeRestart;

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: Listenable.merge([session, _LaunchRefresh(launch)]),
    debugLogDiagnostics: kDebugMode,
    redirect: redirect.call,
    observers: [pages],
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, state) => _homeTab(
          state,
          pages,
          restart: homeRestart = switch (state.extra) {
            final HomeRestart restart => restart,
            _ => homeRestart,
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.foundation,
        builder: (_, _) => const FoundationPage(),
      ),
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
                await session.upgrade(account);
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
              // Home opens on the first lesson's bubble (D-045).
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
              // Home opens on the first lesson's bubble (D-045).
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
      GoRoute(
        path: AppRoutes.placementQuestions,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<PlacementTestCubit>()..start(),
          child: PlacementTestPage(
            onStop: () => context.pop(),
            // `go` leaves the test behind: back never returns to it.
            onFinished: (attemptId) =>
                context.go(AppRoutes.placementResult, extra: attemptId),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.placementResult,
        redirect: (_, state) => state.extra is String ? null : AppRoutes.home,
        builder: (context, state) => BlocProvider(
          create: (_) =>
              sl<PlacementResultCubit>(param1: state.extra! as String)..load(),
          child: PlacementResultPage(
            onStart: () => context.go(AppRoutes.home),
            onLeave: () => context.go(AppRoutes.home),
          ),
        ),
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
        path: AppRoutes.lessonGrammar,
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    sl<GrammarLessonCubit>(param1: lessonId)..start(),
              ),
              BlocProvider(
                create: (_) =>
                    sl<TeacherQuestionsCubit>(param1: lessonId)..load(),
              ),
            ],
            child: GrammarLessonPage(
              onStartExercises: () =>
                  context.pushReplacement(AppRoutes.exercisesOf(lessonId)),
              onExit: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.lessonText,
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return BlocProvider(
            create: (_) => sl<InteractiveTextCubit>(param1: lessonId)..start(),
            child: InteractiveTextPage(
              onExit: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
              onContinue: (shadowing) => shadowing
                  ? context.push(AppRoutes.shadowingOf(lessonId))
                  : context.pushReplacement(AppRoutes.exercisesOf(lessonId)),
              onShowWords: () => context.push(AppRoutes.savedWords),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.lessonVideo,
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return BlocProvider(
            create: (_) => sl<InteractiveVideoCubit>(param1: lessonId)..start(),
            child: InteractiveVideoPage(
              onExit: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
              onContinue: (shadowing) => shadowing
                  ? context.push(AppRoutes.shadowingOf(lessonId))
                  : context.pushReplacement(AppRoutes.exercisesOf(lessonId)),
              onShowWords: () => context.push(AppRoutes.savedWords),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.lessonKids,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  sl<KidLessonCubit>(param1: state.pathParameters['lessonId'])
                    ..start(),
            ),
            BlocProvider(create: (_) => sl<MicCubit>()),
          ],
          child: KidLessonPage(
            onExit: () => _back(context),
            // Home, which shows what the lesson changed (D-087).
            onNext: () => context.go(AppRoutes.home),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.lessonVocabulary,
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return BlocProvider(
            create: (_) => sl<VocabLessonCubit>(param1: lessonId)..start(),
            child: VocabLessonPage(
              onExit: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
              onStartExercises: () =>
                  context.pushReplacement(AppRoutes.exercisesOf(lessonId)),
              onShowWords: () => context.push(AppRoutes.savedWords),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.lessonShadowing,
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          void toExercises() =>
              context.pushReplacement(AppRoutes.exercisesOf(lessonId));
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => sl<ShadowingCubit>(param1: lessonId)..start(),
              ),
              BlocProvider(create: (_) => sl<MicCubit>()),
            ],
            child: ShadowingPage(
              onExit: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
              onDone: toExercises,
              onSkip: toExercises,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.lessonExercises,
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => sl<ExerciseCubit>(param1: lessonId)..start(),
              ),
              BlocProvider(create: (_) => sl<MicCubit>()),
            ],
            child: ExercisePage(
              onExit: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
              onFinished: (summary) => context.pushReplacement(
                AppRoutes.completeOf(lessonId),
                extra: summary,
              ),
              onExplain: (request) => showExplainSheet(
                context,
                cubit: () => sl<ExplainCubit>(param1: request),
              ),
            ),
          );
        },
      ),
      // "Explain it to me" has no design yet.
      GoRoute(
        path: AppRoutes.lessonComplete,
        // Only a lesson that has just ended has anything to show.
        redirect: (_, state) =>
            state.extra is LessonSummary ? null : AppRoutes.home,
        builder: (context, state) => BlocProvider(
          create: (_) =>
              sl<LessonCompleteCubit>(param1: state.extra! as LessonSummary)
                ..start(),
          child: LessonCompletePage(
            onNext: (next) => switch (next.lessonId) {
              final lessonId? => context.pushReplacement(
                lessonPath(
                  id: lessonId,
                  kind: next.lessonKind,
                  scenarioId: next.scenarioId,
                ),
              ),
              null => context.push(AppRoutes.unitStart),
            },
            // Back to the unit it was opened from.
            onBack: () => _back(context),
            onWords: () => context.push(AppRoutes.savedWords),
          ),
        ),
      ),
      // The learner's words, a unit's review and the next unit have no design yet.
      GoRoute(
        path: AppRoutes.savedWords,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<MyWordsCubit>()..start(),
          child: MyWordsPage(onBack: () => _back(context)),
        ),
      ),
      GoRoute(
        path: AppRoutes.practice,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<PracticeCubit>()..start(),
          child: BlocSelector<PracticeCubit, PracticeState, int>(
            selector: (state) => state.badge,
            builder: (context, badge) => TabShell(
              current: AppTab.practice,
              badges: {AppTab.practice: badge},
              onSelect: (tab) => _openTab(context, tab),
              child: PracticePage(
                onReview: () => context.push<void>(AppRoutes.practiceReview),
                onWords: () => context.push<void>(AppRoutes.savedWords),
                onConcepts: () =>
                    context.push<void>(AppRoutes.practiceConcepts),
                // Saving sentences, and shadowing them from here, aren't sent.
                onSentences: () => context.push(AppRoutes.practiceSentences),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.practiceReview,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<ReviewCubit>()..start(),
          child: ReviewPage(onExit: () => _back(context)),
        ),
      ),
      GoRoute(
        path: AppRoutes.practiceConcepts,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<ConceptsCubit>()..start(),
          child: ConceptsPage(
            onBack: () => _back(context),
            onStart: () async =>
                await context.push<Set<String>>(
                  AppRoutes.practiceConceptSession,
                ) ??
                const {},
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.practiceConceptSession,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<ConceptSessionCubit>()..start(),
          child: ConceptSessionPage(
            onExit: (mastered) => context.canPop()
                ? context.pop(mastered)
                : context.go(AppRoutes.practice),
            onExplain: (request) => showExplainSheet(
              context,
              cubit: () => sl<ExplainCubit>(param1: request),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.practiceSentences,
        builder: (_, _) => PendingPage(title: 'practice_sentences_title'.tr()),
      ),
      GoRoute(
        path: AppRoutes.talk,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<TalkCubit>()..start(),
          child: TabShell(
            current: AppTab.talk,
            onSelect: (tab) => _openTab(context, tab),
            child: TalkPage(
              onOpen: (scenario) =>
                  context.push<void>(AppRoutes.talkScenarioOf(scenario.id)),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.kidsWords,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<KidWordsCubit>()..start(),
          child: KidTabShell(
            current: KidTab.words,
            onSelect: (tab) => switch (tab) {
              KidTab.learn => context.go(AppRoutes.home),
              KidTab.words => null,
              KidTab.me => context.go(AppRoutes.me),
            },
            child: KidWordsPage(
              onPlay: () => context.push<void>(AppRoutes.kidsReview),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.kidsReview,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<ReviewCubit>()..start(),
          child: KidReviewPage(
            voice:
                sl<PracticeRepository>().keptBank?.kidsVoice ??
                const KidWordsVoice(),
            onExit: () => _back(context),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.talkScenario,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => sl<ConversationCubit>(
                param1: state.pathParameters['scenarioId'],
              )..start(),
            ),
            BlocProvider(create: (_) => sl<MicCubit>()),
          ],
          child: ConversationPage(onClose: () => _back(context)),
        ),
      ),
      GoRoute(
        path: AppRoutes.me,
        builder: (context, _) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<MeCubit>()..start()),
            BlocProvider(create: (_) => sl<VerifyEmailCubit>()..load()),
            BlocProvider(create: (_) => sl<AccountCubit>()),
          ],
          child: Builder(
            builder: (context) {
              final page = MePage(
                actions: MeActions(
                  onSettings: () => context.push<void>(AppRoutes.meSettings),
                  onPrivacy: () => context.push<void>(AppRoutes.legalPrivacy),
                  onWhatsApp: (number) => sl<ExternalLink>().open(
                    Uri.https('wa.me', number.replaceAll(RegExp('[^0-9]'), '')),
                  ),
                  onPractice: () => context.go(AppRoutes.practice),
                  onCreateAccount: () => context.push<void>(AppRoutes.signUp),
                  onSignOut: context.read<AccountCubit>().signOut,
                  onVerifyEmail: () => showVerifyEmailSheet(context),
                  onRetest: () =>
                      context.push<void>(AppRoutes.onboardingPlacement),
                  onJoin: (track) => context.push<void>(
                    AppRoutes.meJoin,
                    extra: track.title.of(context.locale.languageCode),
                  ),
                ),
              );
              return BlocSelector<MeCubit, MeState, bool>(
                selector: MePage.isKids,
                builder: (context, kids) => kids
                    ? KidTabShell(
                        current: KidTab.me,
                        onSelect: (tab) => switch (tab) {
                          KidTab.learn => context.go(AppRoutes.home),
                          KidTab.words => context.go(AppRoutes.kidsWords),
                          KidTab.me => null,
                        },
                        child: page,
                      )
                    : TabShell(
                        current: AppTab.me,
                        onSelect: (tab) => _openTab(context, tab),
                        child: page,
                      ),
              );
            },
          ),
        ),
      ),
      // The settings screen, and joining another track from «أنا», have no
      // design yet.
      GoRoute(
        path: AppRoutes.meSettings,
        builder: (context, _) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<MeCubit>()..start()),
            BlocProvider(create: (_) => sl<PreferencesCubit>()..start()),
            BlocProvider(create: (_) => sl<VerifyEmailCubit>()..load()),
            BlocProvider(create: (_) => sl<AccountCubit>()),
          ],
          child: Builder(
            builder: (context) => SettingsPage(
              actions: SettingsActions(
                onBack: () => _back(context),
                onWhatsApp: (number) => sl<ExternalLink>().open(
                  Uri.https('wa.me', number.replaceAll(RegExp('[^0-9]'), '')),
                ),
                onPrivacy: () => context.push<void>(AppRoutes.legalPrivacy),
                onTerms: () => context.push<void>(AppRoutes.legalTerms),
                onSignOut: context.read<AccountCubit>().signOut,
                onCreateAccount: () => context.push<void>(AppRoutes.signUp),
                onVerifyEmail: () => showVerifyEmailSheet(context),
                onPassword: () =>
                    context.push<bool>(AppRoutes.meSettingsPassword),
                onDelete: () => context.push<void>(
                  AppRoutes.meSettingsDelete,
                  extra:
                      context.read<MeCubit>().state.profile?.signIn ??
                      SignInMethod.email,
                ),
                version: sl<AppInfo>().version,
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.meSettingsPassword,
        builder: (context, _) => BlocProvider(
          create: (_) => sl<PreferencesCubit>(),
          child: PasswordPage(
            onBack: () => _back(context),
            onSaved: () => context.pop(true),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.meSettingsDelete,
        builder: (context, state) => BlocProvider(
          create: (_) => sl<PreferencesCubit>(),
          child: DeleteAccountPage(
            signIn: state.extra is SignInMethod
                ? state.extra! as SignInMethod
                : SignInMethod.email,
            onBack: () => _back(context),
            // Signing in again with Google or Apple isn't built (D-031).
            onReauthenticate: () async {
              await context.push<void>(AppRoutes.signInWithProvider);
              return false;
            },
            onDone: session.signOut,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.meJoin,
        builder: (_, state) => PendingPage(
          title: state.extra is String ? state.extra! as String : '',
        ),
      ),
      GoRoute(
        path: AppRoutes.unitStart,
        builder: (_, _) => PendingPage(title: 'lesson_done_next_unit'.tr()),
      ),
      // After `unitStart`, so «/units/next» isn't taken for a unit's id.
      GoRoute(
        path: AppRoutes.unit,
        builder: (context, state) => BlocProvider(
          create: (_) =>
              sl<UnitCubit>(param1: state.pathParameters['unitId'])..start(),
          child: UnitPage(
            onBack: () => _back(context),
            onOpen: (lesson, {required kids}) =>
                context.push(_unitLessonPath(lesson, kids: kids)),
            onUnit: (unit) =>
                context.pushReplacement(AppRoutes.unitOf(unit.id)),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) {
          // Like the recovery link, the email is the one way in.
          final token = state.uri.queryParameters['token'] ?? '';
          return BlocProvider(
            key: ValueKey(token),
            create: (_) => sl<EmailLinkCubit>(param1: token)..verify(),
            child: EmailLinkPage(
              onContinue: () => context.go(AppRoutes.home),
              onNewLink: () => session.status == SessionStatus.member
                  ? context.go(
                      AppRoutes.home,
                      extra: const SendEmailLinkRequest(),
                    )
                  : context.go(AppRoutes.signIn),
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

void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(AppRoutes.home);

/// Where a unit's lesson opens ([lessonPath]).
String _unitLessonPath(UnitLesson lesson, {required bool kids}) => lessonPath(
  id: lesson.id,
  kind: lesson.kind,
  scenarioId: lesson.scenarioId,
  kids: kids,
);

/// The «تعلّم» tab (S §6.1): home, under the tabs' bar or a child's one.
/// Its cubit, the email's and «أنا»'s (for the tracks sheet, started only
/// when it opens) live with the route; a dev page scenario ([restart])
/// starts it afresh. [pages] tells it when a lesson or a unit over it closes.
Widget _homeTab(
  GoRouterState state,
  RouteObserver<PageRoute<dynamic>> pages, {
  required HomeRestart? restart,
}) => KeyedSubtree(
  key: ObjectKey(restart),
  child: MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => sl<HomeCubit>()..start()),
      BlocProvider(create: (_) => sl<VerifyEmailCubit>()..load()),
      BlocProvider(create: (_) => sl<MeCubit>()),
    ],
    child: VerifyEmailHost(
      sendLink: state.extra is SendEmailLinkRequest,
      child: Builder(
        builder: (context) {
          // Its cubit's key: the page stays when the bar becomes a child's.
          final page = HomePage(
            key: GlobalObjectKey(context.read<HomeCubit>()),
            pages: pages,
            actions: HomeActions(
              openLesson: (lesson, {required kids}) =>
                  context.push<void>(_unitLessonPath(lesson, kids: kids)),
              openUnit: (unitId) =>
                  context.push<void>(AppRoutes.unitOf(unitId)),
              openReview: () => context.push<void>(
                context.read<HomeCubit>().state.kids
                    ? AppRoutes.kidsReview
                    : AppRoutes.practiceReview,
              ),
              openPlacement: () =>
                  context.push<void>(AppRoutes.onboardingPlacement),
              openMe: () => context.go(AppRoutes.me),
              joinTrack: (track) => context.push<void>(
                AppRoutes.meJoin,
                extra: track.title.of(context.locale.languageCode),
              ),
              openDev: AppConfig.isMock
                  ? () => context.push<void>(AppRoutes.foundation)
                  : null,
            ),
          );
          final shell =
              BlocSelector<HomeCubit, HomeState, ({bool kids, int badge})>(
                selector: (state) =>
                    (kids: HomePage.isKids(state), badge: state.badge),
                builder: (context, tab) => tab.kids
                    ? KidTabShell(
                        current: KidTab.learn,
                        onSelect: (tab) => switch (tab) {
                          KidTab.learn => null,
                          KidTab.words => context.go(AppRoutes.kidsWords),
                          KidTab.me => context.go(AppRoutes.me),
                        },
                        child: page,
                      )
                    : TabShell(
                        current: AppTab.learn,
                        badges: {AppTab.practice: tab.badge},
                        onSelect: (tab) => _openTab(context, tab),
                        child: page,
                      ),
              );
          // A newer version is offered once home has settled, never to a
          // child (design App Update 03).
          return BlocListener<HomeCubit, HomeState>(
            listenWhen: (previous, current) =>
                !_homeSettled(previous) && _homeSettled(current),
            listener: (context, _) =>
                remindToUpdate(context, sl<UpdateReminder>()),
            child: shell,
          );
        },
      ),
    ),
  ),
);

/// Home has its data and its opening and celebrations have played.
bool _homeSettled(HomeState state) =>
    state.home != null &&
    !HomePage.isKids(state) &&
    !state.openingDue &&
    state.moment == null &&
    !state.switching;

/// The tabs' bar.
void _openTab(BuildContext context, AppTab tab) => switch (tab) {
  AppTab.learn => context.go(AppRoutes.home),
  AppTab.practice => context.go(AppRoutes.practice),
  AppTab.talk => context.go(AppRoutes.talk),
  AppTab.me => context.go(AppRoutes.me),
};

/// Runs the route guard again when the opening moves on (ADR 19).
final class _LaunchRefresh extends ChangeNotifier {
  _LaunchRefresh(SplashCubit launch) {
    _changes = launch.stream
        .map((state) => state.launch)
        .distinct()
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<LaunchStatus> _changes;

  @override
  void dispose() {
    unawaited(_changes.cancel());
    super.dispose();
  }
}
