import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/save_progress/cubit/save_progress_cubit.dart';
import 'package:englizia/features/onboarding/presentation/save_progress/pages/save_progress_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_accounts.dart';
import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

const _adult = OnboardingPath(
  audience: TrackAudience.self,
  trackId: 'trk_general',
  entryMethod: TrackEntryMethod.placementTest,
  dailyGoalMinutes: 10,
  challengeDays: 7,
  startLevel: TrackLevel(
    id: 'lvl_prea1',
    order: 1,
    name: LocalizedText(ar: 'Pre-A1', en: 'Pre-A1'),
  ),
);

const _parent = OnboardingPath(
  audience: TrackAudience.child,
  trackId: 'trk_kids',
  trackTitle: LocalizedText(ar: 'مسار الأطفال', en: 'Kids track'),
  entryMethod: TrackEntryMethod.directStart,
  childName: 'سارة',
  childAge: 7,
);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeConnectivityService connectivity;

  /// Guest sessions the page handed on.
  late List<AuthTokens> handedOn;

  setUp(() {
    connectivity = FakeConnectivityService();
    handedOn = [];
  });
  tearDown(() => connectivity.dispose());

  group('SaveProgressCubit', () {
    test(
      'continuing as a guest creates the account and hands its session on',
      () async {
        final accounts = FakeAccountRepository();
        final cubit = SaveProgressCubit(accounts, connectivity);
        addTearDown(cubit.close);

        await cubit.continueAsGuest(
          answers: _adult,
          languageCode: 'ar',
          utcOffsetMinutes: 180,
        );

        expect(accounts.guestAnswers.single, _adult);
        expect(cubit.state.guestSession, guestTokens);
        expect(cubit.state.busy, isTrue);
      },
    );

    test('a failure is kept for a retry, and the retry clears it', () async {
      final cubit = SaveProgressCubit(
        FakeAccountRepository(
          guestResults: const [Err(NetworkFailure()), Ok(guestTokens)],
        ),
        connectivity,
      );
      addTearDown(cubit.close);

      await cubit.continueAsGuest(
        answers: _adult,
        languageCode: 'ar',
        utcOffsetMinutes: 0,
      );
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.creatingGuest, isFalse);
      expect(cubit.state.guestSession, isNull);

      await cubit.continueAsGuest(
        answers: _adult,
        languageCode: 'ar',
        utcOffsetMinutes: 0,
      );
      expect(cubit.state.guestSession, guestTokens);
    });

    test('follows the connection', () async {
      final cubit = SaveProgressCubit(FakeAccountRepository(), connectivity);
      addTearDown(cubit.close);
      await cubit.start();
      expect(cubit.state.online, isTrue);

      connectivity.online = false;
      await pumpEventQueue();
      expect(cubit.state.online, isFalse);
    });
  });

  group('SaveProgressPage', () {
    Future<SaveProgressCubit> pumpPage(
      WidgetTester tester, {
      OnboardingPath path = _adult,
      FakeAccountRepository? accounts,
      ValueChanged<AccountProvider>? onCreateAccount,
      LayoutCase? layout,
      TargetPlatform? platform,
    }) async {
      final cubit = SaveProgressCubit(
        accounts ?? FakeAccountRepository(),
        connectivity,
      );
      addTearDown(cubit.close);
      await cubit.start();
      final content = BlocProvider.value(
        value: cubit,
        child: SaveProgressPage(
          path: path,
          onCreateAccount: onCreateAccount ?? (_) {},
          onTerms: () {},
          onPrivacy: () {},
          onGuestCreated: handedOn.add,
          onBack: () {},
        ),
      );
      final page = platform == null
          ? content
          : Builder(
              builder: (context) => Theme(
                data: Theme.of(context).copyWith(platform: platform),
                child: content,
              ),
            );
      await tester.pumpLocalized(
        page,
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.settleEntrance(QuestionEntrance.settled);
      return cubit;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.slow * 2);
    }

    testLayouts('lays out without overflow', (tester, layout) async {
      await pumpPage(tester, layout: layout);
      expect(tester.takeException(), isNull);
      connectivity.online = false;
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the plan shows the learner\'s answers', (tester) async {
      await pumpPage(tester);
      expect(find.text('onboarding_save_question'.tr()), findsOneWidget);
      expect(find.text('onboarding_save_plan'.tr()), findsOneWidget);
      expect(find.text('10 دقائق يوميًا'), findsOneWidget);
      expect(find.text('تحدّي 7 أيام'), findsOneWidget);
      expect(find.text('البداية من Pre-A1'), findsOneWidget);
      expect(
        find.bySemanticsLabel('onboarding_progress_complete'.tr()),
        findsOneWidget,
      );
    });

    testWidgets('the placement test shows instead of a starting level', (
      tester,
    ) async {
      await pumpPage(tester, path: _adult.copyWith(placementTest: true));
      expect(find.text('onboarding_save_test'.tr()), findsOneWidget);
      expect(find.text('البداية من Pre-A1'), findsNothing);
    });

    testWidgets('a parent saves the child\'s progress in their own name', (
      tester,
    ) async {
      await pumpPage(tester, path: _parent);
      expect(find.text('احفظ تقدّم سارة حتى لا يضيع'), findsOneWidget);
      expect(find.text('سارة، 7 سنوات'), findsOneWidget);
      expect(find.text('مسار الأطفال'), findsOneWidget);
      expect(find.text('onboarding_save_parent_note'.tr()), findsOneWidget);
    });

    testWidgets('each way to create the account is passed on', (tester) async {
      final chosen = <AccountProvider>[];
      await pumpPage(tester, onCreateAccount: chosen.add);

      await tester.tap(find.text('onboarding_save_google'.tr()));
      await tester.tap(find.text('onboarding_save_email'.tr()));
      expect(chosen, [AccountProvider.google, AccountProvider.email]);
      expect(find.text('onboarding_save_apple'.tr()), findsNothing);
    });

    testWidgets('Apple comes first on iOS', (tester) async {
      final chosen = <AccountProvider>[];
      await pumpPage(
        tester,
        platform: TargetPlatform.iOS,
        onCreateAccount: chosen.add,
      );
      final apple = tester.getTopLeft(find.text('onboarding_save_apple'.tr()));
      final google = tester.getTopLeft(
        find.text('onboarding_save_google'.tr()),
      );
      expect(apple.dy, lessThan(google.dy));

      await tester.tap(find.text('onboarding_save_apple'.tr()));
      expect(chosen, [AccountProvider.apple]);
    });

    testWidgets('«لاحقًا» explains, and going back keeps the learner here', (
      tester,
    ) async {
      final accounts = FakeAccountRepository();
      await pumpPage(tester, accounts: accounts);

      await tester.tap(find.text('onboarding_save_later'.tr()));
      await settle(tester);
      expect(find.text('onboarding_save_guest_title'.tr()), findsOneWidget);

      await tester.tap(find.text('onboarding_save_guest_create'.tr()));
      await settle(tester);
      expect(find.text('onboarding_save_guest_title'.tr()), findsNothing);
      expect(accounts.guestAnswers, isEmpty);
      expect(handedOn, isEmpty);
    });

    testWidgets(
      'continuing as a guest sends the answers and hands the guest on',
      (tester) async {
        final accounts = FakeAccountRepository();
        await pumpPage(tester, accounts: accounts);

        await tester.tap(find.text('onboarding_save_later'.tr()));
        await settle(tester);
        await tester.tap(find.text('onboarding_save_guest_continue'.tr()));
        await settle(tester);

        expect(accounts.guestAnswers.single, _adult);
        expect(handedOn, [guestTokens]);
      },
    );

    testWidgets('a failed guest account says so and offers a retry', (
      tester,
    ) async {
      final accounts = FakeAccountRepository(
        guestResults: const [Err(NetworkFailure()), Ok(guestTokens)],
      );
      await pumpPage(tester, accounts: accounts);

      await tester.tap(find.text('onboarding_save_later'.tr()));
      await settle(tester);
      await tester.tap(find.text('onboarding_save_guest_continue'.tr()));
      await settle(tester);
      expect(find.text('common_retry'.tr()), findsOneWidget);

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(accounts.guestAnswers, hasLength(2));
      expect(handedOn, [guestTokens]);
    });

    testWidgets('offline, every way waits for the connection', (tester) async {
      final chosen = <AccountProvider>[];
      await pumpPage(tester, onCreateAccount: chosen.add);
      connectivity.online = false;
      await settle(tester);

      expect(find.text('onboarding_save_offline'.tr()), findsOneWidget);
      await tester.tap(find.text('onboarding_save_google'.tr()));
      await tester.tap(find.text('onboarding_save_later'.tr()));
      await settle(tester);
      expect(chosen, isEmpty);
      expect(find.text('onboarding_save_guest_title'.tr()), findsNothing);

      connectivity.online = true;
      await settle(tester);
      expect(find.text('onboarding_save_offline'.tr()), findsNothing);
      await tester.tap(find.text('onboarding_save_google'.tr()));
      expect(chosen, [AccountProvider.google]);
    });

    testWidgets('buttons and links meet the tap target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
