import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_cubit.dart';
import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_state.dart';
import 'package:englizia/features/onboarding/presentation/audience/pages/audience_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_track_repository.dart';
import '../../../../helpers/pump_app.dart';

final tracksSelfAndChild = [
  fakeTrack(
    'general',
    TrackAudience.self,
    entryMethod: TrackEntryMethod.placementTest,
  ),
  fakeTrack('kids', TrackAudience.child),
  fakeTrack('extra', null),
];
final publishedSelfAndChild = Ok(tracksSelfAndChild);

void main() {
  setUpAll(initLocalizationForTests);

  group('AudienceCubit', () {
    blocTest<AudienceCubit, AudienceState>(
      'offers only audiences that have a published track',
      build: () =>
          AudienceCubit(FakeTrackRepository(tracks: [publishedSelfAndChild])),
      act: (cubit) => cubit.load(),
      expect: () => [
        const AudienceState(),
        AudienceState(status: LoadStatus.ready, tracks: tracksSelfAndChild),
      ],
      verify: (cubit) => expect(cubit.state.available, {
        TrackAudience.self,
        TrackAudience.child,
      }),
    );

    blocTest<AudienceCubit, AudienceState>(
      'ignores a «soon» choice and accepts an available one',
      build: () =>
          AudienceCubit(FakeTrackRepository(tracks: [publishedSelfAndChild])),
      act: (cubit) async {
        await cubit.load();
        cubit
          ..select(TrackAudience.schoolStudent)
          ..select(TrackAudience.child);
      },
      skip: 2,
      expect: () => [
        AudienceState(
          status: LoadStatus.ready,
          tracks: tracksSelfAndChild,
          selected: TrackAudience.child,
        ),
      ],
      verify: (cubit) => expect(cubit.state.canContinue, isTrue),
    );

    blocTest<AudienceCubit, AudienceState>(
      'the choice leads to its track and entry method',
      build: () =>
          AudienceCubit(FakeTrackRepository(tracks: [publishedSelfAndChild])),
      act: (cubit) async {
        await cubit.load();
        cubit.select(TrackAudience.self);
      },
      verify: (cubit) => expect(
        cubit.state.path,
        const OnboardingPath(
          audience: TrackAudience.self,
          trackId: 'general',
          entryMethod: TrackEntryMethod.placementTest,
        ),
      ),
    );

    blocTest<AudienceCubit, AudienceState>(
      'drops a choice whose track was hidden on reload',
      build: () => AudienceCubit(
        FakeTrackRepository(
          tracks: [
            publishedSelfAndChild,
            Ok([fakeTrack('general', TrackAudience.self)]),
          ],
        ),
      ),
      act: (cubit) async {
        await cubit.load();
        cubit.select(TrackAudience.child);
        await cubit.load();
      },
      verify: (cubit) {
        expect(cubit.state.selected, isNull);
        expect(cubit.state.available, {TrackAudience.self});
      },
    );

    blocTest<AudienceCubit, AudienceState>(
      'reports a failure and recovers on retry',
      build: () => AudienceCubit(
        FakeTrackRepository(
          tracks: [const Err(NetworkFailure()), publishedSelfAndChild],
        ),
      ),
      act: (cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => [
        const AudienceState(),
        const AudienceState(
          status: LoadStatus.failure,
          failure: NetworkFailure(),
        ),
        const AudienceState(),
        AudienceState(status: LoadStatus.ready, tracks: tracksSelfAndChild),
      ],
    );
  });

  group('AudiencePage', () {
    Future<AudienceCubit> pumpPage(
      WidgetTester tester, {
      Result<List<LearningTrack>>? result,
      ValueChanged<OnboardingPath>? onContinue,
      Locale locale = AppLocales.arabic,
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final cubit = AudienceCubit(
        FakeTrackRepository(tracks: [result ?? publishedSelfAndChild]),
      );
      addTearDown(cubit.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: AudiencePage(onContinue: onContinue ?? (_) {}, onBack: () {}),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await cubit.load();
      await tester.settleEntrance(QuestionEntrance.settled);
      return cubit;
    }

    testLayouts('lays out without overflow', (tester, layout) async {
      await pumpPage(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an audience without a published track is «soon»', (
      tester,
    ) async {
      final cubit = await pumpPage(tester);

      expect(find.text('common_soon'.tr()), findsOneWidget);
      await tester.tap(find.text('onboarding_audience_school_title'.tr()));
      await tester.pump();
      expect(cubit.state.selected, isNull);
    });

    testWidgets('continue is off until a choice, then hands it on', (
      tester,
    ) async {
      OnboardingPath? continued;
      await pumpPage(tester, onContinue: (path) => continued = path);

      await tester.tap(find.text('common_continue'.tr()));
      expect(continued, isNull);

      await tester.tap(find.text('onboarding_audience_child_title'.tr()));
      await tester.pump(AppMotion.fast);
      await tester.tap(find.text('common_continue'.tr()));
      expect(continued?.audience, TrackAudience.child);
      expect(continued?.trackId, 'kids');
    });

    testWidgets('the progress follows the chosen path', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = await pumpPage(
        tester,
        result: Ok([
          fakeTrack('general', TrackAudience.self),
          fakeTrack(
            'emar',
            TrackAudience.schoolStudent,
            entryMethod: TrackEntryMethod.gradeSelection,
          ),
        ]),
      );
      // Before a choice: the common path, with the level question.
      expect(find.bySemanticsLabel('الخطوة 2 من 7'), findsOneWidget);

      // This adult track starts directly, so there is no level question.
      cubit.select(TrackAudience.self);
      await tester.pump();
      expect(find.bySemanticsLabel('الخطوة 2 من 6'), findsOneWidget);

      cubit.select(TrackAudience.schoolStudent);
      await tester.pump();
      expect(find.bySemanticsLabel('الخطوة 2 من 7'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final cubit = await pumpPage(tester, result: const Err(NetworkFailure()));

      expect(cubit.state.status, LoadStatus.failure);
      expect(find.text('common_retry'.tr()), findsOneWidget);
    });

    testWidgets('has no undersized or unlabeled tap targets', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, size: narrowViewport);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
