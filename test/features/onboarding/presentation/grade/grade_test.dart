import 'package:bloc_test/bloc_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_cubit.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_state.dart';
import 'package:englizia/features/onboarding/presentation/grade/pages/grade_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_track_repository.dart';
import '../../../../helpers/pump_app.dart';

final schoolTracks = Ok([
  fakeTrack('general', TrackAudience.self),
  fakeTrack('emar', TrackAudience.schoolStudent),
]);

final twelveGrades = Ok([
  for (var g = 1; g <= 12; g++)
    fakeGrade(
      g,
      group: g <= 6
          ? 'الحلقة الأولى'
          : g <= 9
          ? 'الحلقة الثانية'
          : 'الثانوية',
    ),
]);

void main() {
  setUpAll(initLocalizationForTests);

  group('GradeCubit', () {
    test('loads the levels of the school track', () async {
      final repo = FakeTrackRepository(
        tracks: [schoolTracks],
        levels: [twelveGrades],
      );
      final cubit = GradeCubit(repo);
      await cubit.load();

      expect(repo.levelRequests, ['emar']);
      expect(cubit.state.status, GradeStatus.ready);
      expect(cubit.state.groups.map((g) => g.levels.length), [6, 3, 3]);
      expect(cubit.state.groups.first.title?.ar, 'الحلقة الأولى');
    });

    test(
      'prefers a grade-selection track when several are suggested',
      () async {
        final repo = FakeTrackRepository(
          tracks: [
            Ok([
              fakeTrack('other', TrackAudience.schoolStudent),
              fakeTrack(
                'emar',
                TrackAudience.schoolStudent,
                entryMethod: TrackEntryMethod.gradeSelection,
              ),
            ]),
          ],
          levels: [twelveGrades],
        );
        await GradeCubit(repo).load();
        expect(repo.levelRequests, ['emar']);
      },
    );

    blocTest<GradeCubit, GradeState>(
      'fails when no school track is published any more',
      build: () => GradeCubit(
        FakeTrackRepository(
          tracks: [
            Ok([fakeTrack('general', TrackAudience.self)]),
          ],
        ),
      ),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => const [
        GradeState(status: GradeStatus.failure, failure: NotFoundFailure()),
      ],
    );

    test('levels without groups stay together', () {
      final groups = GradeCubit.groupLevels([
        const TrackLevel(id: 'a', order: 1, name: LocalizedTextFixture.a),
        const TrackLevel(id: 'b', order: 2, name: LocalizedTextFixture.a),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.title, isNull);
    });

    test('selecting enables continue', () async {
      final cubit = GradeCubit(
        FakeTrackRepository(tracks: [schoolTracks], levels: [twelveGrades]),
      );
      await cubit.load();
      expect(cubit.state.canContinue, isFalse);
      cubit.select(cubit.state.groups[1].levels.first);
      expect(cubit.state.canContinue, isTrue);
      expect(cubit.state.selected?.schoolGrade, 7);
    });
  });

  group('GradePage', () {
    Future<GradeCubit> pumpPage(
      WidgetTester tester, {
      ValueChanged<TrackLevel>? onContinue,
      Locale locale = AppLocales.arabic,
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final cubit = GradeCubit(
        FakeTrackRepository(tracks: [schoolTracks], levels: [twelveGrades]),
      );
      addTearDown(cubit.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: GradePage(onContinue: onContinue ?? (_) {}, onBack: () {}),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await cubit.load();
      await tester.settleEntrance(QuestionEntrance.settled);
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

    testWidgets('shows the groups and hands the chosen grade on', (
      tester,
    ) async {
      TrackLevel? chosen;
      await pumpPage(tester, onContinue: (level) => chosen = level);

      expect(find.text('الحلقة الثانية'), findsOneWidget);
      await tester.tap(find.text('common_continue'.tr()));
      expect(chosen, isNull);

      await tester.tap(find.text('7'));
      await tester.pump(AppMotion.fast);
      await tester.tap(find.text('common_continue'.tr()));
      expect(chosen?.schoolGrade, 7);
    });

    testWidgets('grades are radios with names for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final cubit = await pumpPage(tester, size: narrowViewport);
      cubit.select(cubit.state.groups.first.levels.first);
      await tester.pump();

      expect(
        tester.getSemantics(find.text('الصف 1')),
        isSemantics(
          label: 'الصف 1',
          isChecked: true,
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}

abstract final class LocalizedTextFixture {
  static const a = LocalizedText(ar: 'أ');
}
