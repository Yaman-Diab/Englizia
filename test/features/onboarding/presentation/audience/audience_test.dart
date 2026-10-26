import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_motion.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_cubit.dart';
import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_state.dart';
import 'package:englizia/features/onboarding/presentation/audience/pages/audience_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

LearningTrack track(String id, TrackAudience? audience) => LearningTrack(
  id: id,
  title: const LocalizedText(ar: 'مسار'),
  description: const LocalizedText(ar: ''),
  order: 0,
  entryMethod: TrackEntryMethod.directStart,
  audience: audience,
);

/// Serves the queued results in order, then repeats the last one.
class FakeTrackRepository implements TrackRepository {
  FakeTrackRepository(this.results);

  final List<Result<List<LearningTrack>>> results;
  var calls = 0;

  @override
  Future<Result<List<LearningTrack>>> getPublishedTracks() async =>
      results[(calls++).clamp(0, results.length - 1)];
}

final publishedSelfAndChild = Ok([
  track('general', TrackAudience.self),
  track('kids', TrackAudience.child),
  track('extra', null),
]);

void main() {
  setUpAll(initLocalizationForTests);

  group('AudienceCubit', () {
    blocTest<AudienceCubit, AudienceState>(
      'offers only audiences that have a published track',
      build: () => AudienceCubit(FakeTrackRepository([publishedSelfAndChild])),
      act: (cubit) => cubit.load(),
      expect: () => const [
        AudienceState(),
        AudienceState(
          status: AudienceStatus.ready,
          available: {TrackAudience.self, TrackAudience.child},
        ),
      ],
    );

    blocTest<AudienceCubit, AudienceState>(
      'ignores a «soon» choice and accepts an available one',
      build: () => AudienceCubit(FakeTrackRepository([publishedSelfAndChild])),
      act: (cubit) async {
        await cubit.load();
        cubit
          ..select(TrackAudience.schoolStudent)
          ..select(TrackAudience.child);
      },
      skip: 2,
      expect: () => const [
        AudienceState(
          status: AudienceStatus.ready,
          available: {TrackAudience.self, TrackAudience.child},
          selected: TrackAudience.child,
        ),
      ],
      verify: (cubit) => expect(cubit.state.canContinue, isTrue),
    );

    blocTest<AudienceCubit, AudienceState>(
      'drops a choice whose track was hidden on reload',
      build: () => AudienceCubit(
        FakeTrackRepository([
          publishedSelfAndChild,
          Ok([track('general', TrackAudience.self)]),
        ]),
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
        FakeTrackRepository([
          const Err(NetworkFailure()),
          publishedSelfAndChild,
        ]),
      ),
      act: (cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => const [
        AudienceState(),
        AudienceState(
          status: AudienceStatus.failure,
          failure: NetworkFailure(),
        ),
        AudienceState(),
        AudienceState(
          status: AudienceStatus.ready,
          available: {TrackAudience.self, TrackAudience.child},
        ),
      ],
    );
  });

  group('AudiencePage', () {
    Future<AudienceCubit> pumpPage(
      WidgetTester tester, {
      Result<List<LearningTrack>>? result,
      ValueChanged<TrackAudience>? onContinue,
      Locale locale = AppLocales.arabic,
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final cubit = AudienceCubit(
        FakeTrackRepository([result ?? publishedSelfAndChild]),
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
      await tester.pump(AppMotion.heroEntrance);
      return cubit;
    }

    for (final locale in AppLocales.supported) {
      for (final size in [defaultViewport, narrowViewport]) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          testWidgets('lays out without overflow (${locale.languageCode}, '
              '${size.width.toInt()}dp, ${mode.name})', (tester) async {
            await pumpPage(tester, locale: locale, size: size, themeMode: mode);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

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
      TrackAudience? continued;
      await pumpPage(tester, onContinue: (a) => continued = a);

      await tester.tap(find.text('common_continue'.tr()));
      expect(continued, isNull);

      await tester.tap(find.text('onboarding_audience_child_title'.tr()));
      await tester.pump(AppMotion.fast);
      await tester.tap(find.text('common_continue'.tr()));
      expect(continued, TrackAudience.child);
    });

    testWidgets('the progress follows the chosen path', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = await pumpPage(
        tester,
        result: Ok([
          track('general', TrackAudience.self),
          track('emar', TrackAudience.schoolStudent),
        ]),
      );
      expect(find.bySemanticsLabel('الخطوة 2 من 4'), findsOneWidget);

      cubit.select(TrackAudience.schoolStudent);
      await tester.pump();
      expect(find.bySemanticsLabel('الخطوة 2 من 5'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final cubit = await pumpPage(tester, result: const Err(NetworkFailure()));

      expect(cubit.state.status, AudienceStatus.failure);
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
