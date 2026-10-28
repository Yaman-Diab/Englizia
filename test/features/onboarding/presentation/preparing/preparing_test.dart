import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/preparing/cubit/preparing_cubit.dart';
import 'package:englizia/features/onboarding/presentation/preparing/pages/preparing_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/entities/track_unit.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_accounts.dart';
import '../../../../helpers/fake_placement_repository.dart';
import '../../../../helpers/fake_settings_repository.dart';
import '../../../../helpers/fake_track_repository.dart';
import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

const _preA1 = TrackLevel(
  id: 'lvl_gen_prea1',
  order: 1,
  name: LocalizedText(ar: 'Pre-A1', en: 'Pre-A1'),
);

const _seventh = TrackLevel(
  id: 'lvl_emar_07',
  order: 7,
  name: LocalizedText(ar: 'السابع', en: 'Grade 7'),
  schoolGrade: 7,
);

const _hello = TrackUnit(
  id: 'u1',
  order: 1,
  title: 'Hello!',
  topic: LocalizedText(ar: 'التحيات والتعارف', en: 'Greetings'),
);

const _fromZero = OnboardingPath(
  audience: TrackAudience.self,
  trackId: 'trk_general',
  dailyGoalMinutes: 15,
  startLevel: _preA1,
);

void main() {
  setUpAll(initLocalizationForTests);

  late AppSessionController session;
  late FakeTrackRepository tracks;
  late FakePlacementRepository placement;
  late FakeSettingsRepository settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app.has_launched': true});
    session = AppSessionController(
      tokens: FakeTokenStorage(),
      settings: SettingsStorageService(await SharedPreferences.getInstance()),
    );
    await session.bootstrap();
    tracks = FakeTrackRepository(
      levels: const [
        Ok([_preA1]),
      ],
      units: const [
        Ok([_hello]),
      ],
    );
    placement = FakePlacementRepository();
    settings = FakeSettingsRepository();
  });

  PreparingCubit cubit({Duration minimumStep = Duration.zero}) {
    final cubit = PreparingCubit(
      session,
      tracks,
      placement,
      settings,
      minimumStep: minimumStep,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  List<PreparingStepStatus> statuses(PreparingCubit cubit) => [
    for (final step in cubit.state.steps) step.status,
  ];

  group('PreparingCubit', () {
    test('each branch has its own three steps', () {
      expect(PreparingCubit.stepsFor(_fromZero), [
        PreparingStepKind.level,
        PreparingStepKind.unit,
        PreparingStepKind.goal,
      ]);
      expect(
        PreparingCubit.stepsFor(
          const OnboardingPath(
            audience: TrackAudience.schoolStudent,
            grade: _seventh,
          ),
        ),
        [
          PreparingStepKind.grade,
          PreparingStepKind.unit,
          PreparingStepKind.goal,
        ],
      );
      expect(PreparingCubit.stepsFor(_fromZero.copyWith(placementTest: true)), [
        PreparingStepKind.plan,
        PreparingStepKind.test,
        PreparingStepKind.goal,
      ]);
    });

    test(
      'starts the session, then loads the first unit and the goal',
      () async {
        final preparing = cubit();
        await preparing.start(path: _fromZero, account: memberTokens);

        expect(session.status, SessionStatus.member);
        expect(preparing.state.ready, isTrue);
        expect(preparing.state.level, _preA1);
        expect(tracks.unitRequests, ['lvl_gen_prea1']);
        expect(preparing.state.unit, _hello);
        expect(preparing.state.goalMinutes, 15);
      },
    );

    test('a guest starts a guest session', () async {
      await cubit().start(path: _fromZero, account: guestTokens);
      expect(session.status, SessionStatus.guest);
    });

    test('runs one step at a time', () async {
      final preparing = cubit(minimumStep: const Duration(milliseconds: 10));
      final running = preparing.start(path: _fromZero, account: memberTokens);
      expect(statuses(preparing), [
        PreparingStepStatus.running,
        PreparingStepStatus.pending,
        PreparingStepStatus.pending,
      ]);
      await running;
      expect(statuses(preparing), everyElement(PreparingStepStatus.done));
    });

    test('a track without a level step starts at its first level', () async {
      final preparing = cubit();
      await preparing.start(
        path: const OnboardingPath(
          audience: TrackAudience.self,
          trackId: 'trk_general',
        ),
        account: memberTokens,
      );
      expect(tracks.levelRequests, ['trk_general']);
      expect(preparing.state.level, _preA1);
      // No goal chosen: the setting's default.
      expect(preparing.state.goalMinutes, 10);
    });

    test('the test branch loads the placement test', () async {
      final preparing = cubit();
      await preparing.start(
        path: _fromZero.copyWith(placementTest: true),
        account: memberTokens,
      );
      expect(preparing.state.takesTest, isTrue);
      expect(preparing.state.test, testPlacementSummary);
      expect(tracks.unitRequests, isEmpty);
    });

    test('a failed step waits, and the retry resumes from it', () async {
      tracks = FakeTrackRepository(
        units: const [
          Err(NetworkFailure()),
          Ok([_hello]),
        ],
      );
      final preparing = cubit();
      await preparing.start(path: _fromZero, account: memberTokens);

      expect(statuses(preparing), [
        PreparingStepStatus.done,
        PreparingStepStatus.failed,
        PreparingStepStatus.pending,
      ]);
      expect(preparing.state.failure, isA<NetworkFailure>());
      expect(preparing.state.failed, isTrue);

      await preparing.retry();
      expect(preparing.state.ready, isTrue);
      expect(preparing.state.failure, isNull);
      expect(tracks.unitRequests, hasLength(2));
    });
  });

  group('PreparingPage', () {
    Future<PreparingCubit> pumpPage(
      WidgetTester tester, {
      OnboardingPath path = _fromZero,
      String name = 'أحمد',
      Duration minimumStep = Duration.zero,
      VoidCallback? onStartLesson,
      VoidCallback? onStartTest,
      LayoutCase? layout,
    }) async {
      final preparing = cubit(minimumStep: minimumStep);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: preparing,
          child: PreparingPage(
            name: name,
            onStartLesson: onStartLesson ?? () {},
            onStartTest: onStartTest ?? () {},
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      unawaited(preparing.start(path: path, account: memberTokens));
      return preparing;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.slow * 2);
    }

    AppButton action(WidgetTester tester) =>
        tester.widget<AppButton>(find.byType(AppButton));

    testLayouts('lays out without overflow', (tester, layout) async {
      await pumpPage(tester, layout: layout);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('preparing_start_lesson'.tr()), findsOneWidget);
    });

    testWidgets('while preparing: the guide works, the button waits hidden', (
      tester,
    ) async {
      await pumpPage(tester, minimumStep: const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('preparing_title'.tr()), findsOneWidget);
      expect(
        tester.widget<Mascot>(find.byType(Mascot)).expression,
        MascotExpression.focused,
      );
      expect(action(tester).onPressed, isNull);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(
                of: find.byType(AppButton),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        0,
      );
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('ready: the steps say what they found, the guide cheers', (
      tester,
    ) async {
      var started = false;
      await pumpPage(tester, onStartLesson: () => started = true);
      await settle(tester);

      expect(find.text('كل شيء جاهز يا أحمد'), findsOneWidget);
      expect(
        find.text('اخترنا مستواك: ${Unicode.LRI}Pre-A1${Unicode.PDI}'),
        findsOneWidget,
      );
      expect(find.text('جهّزنا وحدتك الأولى'), findsOneWidget);
      expect(
        find.text('${Unicode.LRI}Hello!${Unicode.PDI} التحيات والتعارف'),
        findsOneWidget,
      );
      expect(find.text('ضبطنا هدفك اليومي: 15 دقيقة'), findsOneWidget);
      expect(
        tester.widget<Mascot>(find.byType(Mascot)).expression,
        MascotExpression.excited,
      );

      await tester.tap(find.text('preparing_start_lesson'.tr()));
      expect(started, isTrue);
    });

    testWidgets('without a name the title says it plainly', (tester) async {
      await pumpPage(tester, name: '');
      await settle(tester);
      expect(find.text('preparing_ready'.tr()), findsOneWidget);
    });

    testWidgets('a school student sees the grade and the book unit', (
      tester,
    ) async {
      tracks = FakeTrackRepository(
        units: const [
          Ok([TrackUnit(id: 'u', order: 1, title: 'Unit 1: Back to School')]),
        ],
      );
      await pumpPage(
        tester,
        path: const OnboardingPath(
          audience: TrackAudience.schoolStudent,
          grade: _seventh,
          dailyGoalMinutes: 10,
        ),
      );
      await settle(tester);
      expect(find.text('اخترنا صفّك: السابع'), findsOneWidget);
      expect(
        find.text('${Unicode.LRI}Unit 1: Back to School${Unicode.PDI}'),
        findsOneWidget,
      );
    });

    testWidgets('the test branch offers the test', (tester) async {
      var started = false;
      await pumpPage(
        tester,
        path: _fromZero.copyWith(placementTest: true),
        onStartTest: () => started = true,
      );
      await settle(tester);
      expect(find.text('حفظنا خطتك'), findsOneWidget);
      expect(
        find.text('${Unicode.LRI}12–15${Unicode.PDI} دقيقة'),
        findsOneWidget,
      );
      await tester.tap(find.text('preparing_start_test'.tr()));
      expect(started, isTrue);
    });

    testWidgets('a failed step says why, and the button retries it', (
      tester,
    ) async {
      tracks = FakeTrackRepository(
        units: const [
          Err(NetworkFailure()),
          Ok([_hello]),
        ],
      );
      await pumpPage(tester);
      await settle(tester);

      expect(find.text('preparing_unit_failed'.tr()), findsOneWidget);
      expect(find.text('error_network'.tr()), findsOneWidget);
      expect(find.text('preparing_title'.tr()), findsOneWidget);
      expect(
        tester.widget<Mascot>(find.byType(Mascot)).expression,
        MascotExpression.understand,
      );

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(find.text('preparing_start_lesson'.tr()), findsOneWidget);
    });

    testWidgets('the button meets the tap target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      await settle(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
