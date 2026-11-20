import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';
import 'package:englizia/features/placement/presentation/result/cubit/placement_result_cubit.dart';
import 'package:englizia/features/placement/presentation/result/pages/placement_result_page.dart';
import 'package:englizia/features/placement/presentation/result/widgets/level_ladder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_placement_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _atFirst = PlacementResult(
  levels: testLevels,
  levelIndex: 0,
  skills: testSkills,
);

const _atA1 = PlacementResult(
  levels: testLevels,
  levelIndex: 1,
  skills: testSkills,
  canLower: true,
);

FakePlacementRepository _with(
  List<Result<PlacementResult>> results, {
  List<Result<void>> accepts = const [Ok(null)],
}) => FakePlacementRepository(
  const [Ok(testPlacementSummary)],
  const [],
  const [Ok(null)],
  const [Ok(testAttempt)],
  const [Ok([])],
  const [Ok(null)],
  results,
  accepts,
);

void main() {
  setUpAll(initLocalizationForTests);

  PlacementResultCubit cubitWith(FakePlacementRepository placement) {
    final cubit = PlacementResultCubit(placement, attemptId: 'att');
    addTearDown(cubit.close);
    return cubit;
  }

  group('PlacementResultCubit', () {
    test('opens on the measured level', () async {
      final cubit = cubitWith(FakePlacementRepository());
      await cubit.load();
      expect(cubit.state.view, PlacementResultView.ready);
      expect(cubit.state.level?.code, 'A2');
      expect(cubit.state.lowerLevel?.code, 'A1');
      expect(cubit.state.isTopLevel, isTrue);
    });

    test('no connection waits; a retry brings the result', () async {
      final cubit = cubitWith(
        _with(const [Err(NetworkFailure()), Ok(testResult)]),
      );
      await cubit.load();
      expect(cubit.state.view, PlacementResultView.offline);

      final retry = cubit.load();
      expect(cubit.state.view, PlacementResultView.offline);
      expect(cubit.state.retrying, isTrue);
      await retry;
      expect(cubit.state.view, PlacementResultView.ready);
      expect(cubit.state.retrying, isFalse);
    });

    test(
      'the result arrives with its achievement, offline with none',
      () async {
        final sounds = FakeSoundPlayer();
        final cubit = PlacementResultCubit(
          _with(const [Err(NetworkFailure()), Ok(testResult)]),
          attemptId: 'att',
          sounds: sounds,
        );
        addTearDown(cubit.close);

        await cubit.load();
        expect(sounds.played, isEmpty);
        await cubit.load();
        expect(sounds.played, [AppSound.achievement]);
      },
    );

    test('another failure leaves a retry', () async {
      final cubit = cubitWith(
        _with(const [Err(ServerFailure()), Ok(testResult)]),
      );
      await cubit.load();
      expect(cubit.state.view, PlacementResultView.failed);
      await cubit.load();
      expect(cubit.state.view, PlacementResultView.ready);
    });

    test('lowering goes one level down, once, keeping the skills', () async {
      final cubit = cubitWith(FakePlacementRepository());
      await cubit.load();
      cubit.lower();
      expect(cubit.state.level?.code, 'A1');
      expect(cubit.state.lowered, isTrue);
      expect(cubit.state.lowerLevel, isNull);
      expect(cubit.state.isTopLevel, isFalse);
      expect(cubit.state.result?.skills, testSkills);

      cubit.lower();
      expect(cubit.state.level?.code, 'A1');
    });

    test(
      'a track with nothing below the result offers nothing lower',
      () async {
        final cubit = cubitWith(
          _with(const [
            Ok(
              PlacementResult(
                levels: testLevels,
                levelIndex: 2,
                skills: testSkills,
              ),
            ),
          ]),
        );
        await cubit.load();
        expect(cubit.state.lowerLevel, isNull);
        cubit.lower();
        expect(cubit.state.levelIndex, 2);
      },
    );

    test('the first level has nothing lower', () async {
      final cubit = cubitWith(_with(const [Ok(_atFirst)]));
      await cubit.load();
      expect(cubit.state.isFirstLevel, isTrue);
      expect(cubit.state.lowerLevel, isNull);
      cubit.lower();
      expect(cubit.state.levelIndex, 0);
    });

    test('accepting sends the level chosen', () async {
      final placement = FakePlacementRepository();
      final cubit = cubitWith(placement);
      await cubit.load();
      cubit.lower();
      await cubit.accept();
      expect(placement.accepted, [true]);
      expect(cubit.state.accepted, isTrue);
    });

    test('a failed accept stays, for a retry', () async {
      final placement = _with(
        const [Ok(testResult)],
        accepts: const [Err(NetworkFailure()), Ok(null)],
      );
      final cubit = cubitWith(placement);
      await cubit.load();
      await cubit.accept();
      expect(cubit.state.accepted, isFalse);
      expect(cubit.state.actionFailure, isA<NetworkFailure>());

      await cubit.accept();
      expect(cubit.state.accepted, isTrue);
      expect(cubit.state.actionFailure, isNull);
    });
  });

  group('PlacementResultPage', () {
    late int starts;
    late int leaves;

    setUp(() {
      starts = 0;
      leaves = 0;
    });

    Future<PlacementResultCubit> pumpPage(
      WidgetTester tester,
      FakePlacementRepository placement, {
      LayoutCase? layout,
      Size? size,
      bool settle = true,
    }) async {
      final cubit = cubitWith(placement);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementResultPage(
            onStart: () => starts++,
            onLeave: () => leaves++,
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: size ?? layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await cubit.load();
      await tester.pump();
      if (settle) {
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
      }
      return cubit;
    }

    for (final (name, result) in const <(String, PlacementResult)>[
      ('the top level', testResult),
      ('the first level', _atFirst),
      ('a level between', _atA1),
    ]) {
      testLayouts('$name lays out without overflow', (tester, layout) async {
        await pumpPage(tester, _with([Ok(result)]), layout: layout);
        expect(tester.takeException(), isNull);
      });
    }

    testLayouts('offline lays out without overflow', (tester, layout) async {
      await pumpPage(
        tester,
        _with(const [Err(NetworkFailure())]),
        layout: layout,
      );
      expect(tester.takeException(), isNull);
    });

    testLayouts('waiting lays out without overflow', (tester, layout) async {
      final cubit = cubitWith(FakePlacementRepository());
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementResultPage(onStart: () {}, onLeave: () {}),
        ),
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing while still waiting leaves no error', (tester) async {
      final cubit = cubitWith(FakePlacementRepository());
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementResultPage(onStart: () {}, onLeave: () {}),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('waiting: the empty ladder and the one spinner', (
      tester,
    ) async {
      final cubit = cubitWith(FakePlacementRepository());
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementResultPage(onStart: () {}, onLeave: () {}),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('placement_result_computing'.tr()), findsOneWidget);
      expect(find.byType(AppSpinner), findsOneWidget);
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.focused);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('a result: level, what you can do, skills and the note', (
      tester,
    ) async {
      await pumpPage(tester, _with(const [Ok(_atA1)]));
      expect(find.text('placement_result_estimated'.tr()), findsOneWidget);
      // On the ladder and as the level.
      expect(find.text('A1'), findsNWidgets(2));
      // The level in a word, as the panel wrote it; not its name.
      expect(find.text('مبتدئ'), findsOneWidget);
      expect(find.text('المستوى الثاني'), findsNothing);
      expect(find.text('placement_result_can'.tr()), findsOneWidget);
      // What the level can do: the panel's sentences, in their order.
      final lines = [
        for (final line in testLevels[1].canDo)
          tester.getTopLeft(find.text(line.ar)).dy,
      ];
      expect(lines, hasLength(3));
      expect(lines, orderedEquals([...lines]..sort()));
      expect(find.text('placement_result_skills'.tr()), findsOneWidget);
      expect(find.text('placement_skill_vocabulary'.tr()), findsOneWidget);
      expect(find.text('placement_result_note'.tr()), findsOneWidget);
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.happy);
      expect(guide.sparkles, isFalse);
    });

    testWidgets('skills: bars relative to the strongest, with no numbers', (
      tester,
    ) async {
      await pumpPage(tester, _with(const [Ok(_atA1)]));
      expect(find.text('placement_skill_strongest'.tr()), findsOneWidget);
      expect(find.text('placement_skill_needs_work'.tr()), findsOneWidget);
      final bars = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((b) => b.widthFactor);
      expect(bars, [1.0, .75, .5]);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('75'), findsNothing);
    });

    testWidgets('equal skills get no badges', (tester) async {
      await pumpPage(
        tester,
        _with(const [
          Ok(
            PlacementResult(
              levels: testLevels,
              levelIndex: 1,
              skills: [
                PlacementSkill(kind: PlacementSkillKind.grammar, score: .5),
                PlacementSkill(kind: PlacementSkillKind.reading, score: .5),
              ],
            ),
          ),
        ]),
      );
      expect(find.text('placement_skill_strongest'.tr()), findsNothing);
      expect(find.text('placement_skill_needs_work'.tr()), findsNothing);
    });

    testWidgets('a level the panel said nothing of shows neither part', (
      tester,
    ) async {
      // A2 has no word and no sentences.
      await pumpPage(
        tester,
        _with(const [
          Ok(
            PlacementResult(
              levels: testLevels,
              levelIndex: 2,
              skills: testSkills,
            ),
          ),
        ]),
      );

      expect(find.text('A2'), findsNWidgets(2));
      expect(find.text('المستوى الثالث'), findsNothing);
      expect(find.text('placement_result_can'.tr()), findsNothing);
      expect(find.text('placement_result_skills'.tr()), findsOneWidget);
    });

    testWidgets('in English a sentence reads in English, when it has one', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _with(const [Ok(_atA1)]),
        layout: (
          locale: const Locale('en'),
          size: defaultViewport,
          themeMode: ThemeMode.light,
        ),
      );

      expect(find.text('Introduce yourself'), findsOneWidget);
      expect(find.text('تعرّف بنفسك'), findsNothing);
      expect(find.text('تملأ نموذجًا باسمك'), findsOneWidget);
    });

    testWidgets('the first level: from the beginning, nothing lower', (
      tester,
    ) async {
      await pumpPage(tester, _with(const [Ok(_atFirst)]));
      expect(find.text('placement_result_from_start'.tr()), findsOneWidget);
      expect(find.text('البداية'), findsNothing);
      expect(find.text('placement_result_first_week'.tr()), findsOneWidget);
      expect(find.text('تقرأ الحروف'), findsOneWidget);
      expect(find.text('onboarding_level_beginner_cta'.tr()), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.encourage);
    });

    testWidgets('the top level says so', (tester) async {
      await pumpPage(tester, FakePlacementRepository());
      expect(find.text('placement_result_top'.tr()), findsOneWidget);
    });

    testWidgets('choosing a lower level asks first, then one hop down', (
      tester,
    ) async {
      final placement = FakePlacementRepository();
      await pumpPage(tester, placement);
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      await tester.pump(AppMotion.sheetIn);
      expect(find.byType(ActionSheet), findsOneWidget);
      expect(find.text('placement_lower_body'.tr()), findsOneWidget);

      // Staying changes nothing.
      await tester.tap(find.byType(AppButton).last);
      await tester.pump();
      await tester.pump(AppMotion.sheetOut);
      expect(find.text('placement_result_estimated'.tr()), findsOneWidget);

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      await tester.pump(AppMotion.sheetIn);
      await tester.tap(
        find
            .descendant(
              of: find.byType(ActionSheet),
              matching: find.byType(AppButton),
            )
            .first,
      );
      await tester.pump();
      await tester.pump(AppMotion.sheetOut);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('placement_result_chose'.tr()), findsOneWidget);
      expect(find.text('placement_result_top'.tr()), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      final ladder = tester.widget<LevelLadder>(find.byType(LevelLadder));
      expect(ladder.level, 1);
      expect(ladder.moment.guidePosition, 1);
      expect(ladder.moment.showSparks, isFalse);
    });

    testWidgets('starting tells the server, then moves on', (tester) async {
      final placement = FakePlacementRepository();
      await pumpPage(tester, placement);
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.pump();
      expect(placement.accepted, [false]);
      expect(starts, 1);
    });

    testWidgets('a failed start says so and retries', (tester) async {
      final placement = _with(
        const [Ok(testResult)],
        accepts: const [Err(NetworkFailure()), Ok(null)],
      );
      await pumpPage(tester, placement);
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(starts, 0);
      expect(find.text('error_network'.tr()), findsOneWidget);

      await tester.tap(find.text('common_retry'.tr()));
      await tester.pump();
      await tester.pump();
      expect(starts, 1);
    });

    testWidgets('offline: reassurance first, then a retry to the result', (
      tester,
    ) async {
      await pumpPage(tester, _with(const [Err(NetworkFailure()), Ok(_atA1)]));
      expect(find.text('placement_result_saved'.tr()), findsOneWidget);
      expect(find.text('placement_result_when_back'.tr()), findsOneWidget);
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.understand);

      await tester.tap(find.text('common_retry'.tr()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('placement_result_estimated'.tr()), findsOneWidget);
    });

    testWidgets('a server failure offers a retry', (tester) async {
      await pumpPage(tester, _with(const [Err(ServerFailure()), Ok(_atA1)]));
      await tester.tap(find.text('common_retry'.tr()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('placement_result_estimated'.tr()), findsOneWidget);
    });

    testWidgets('the system\'s back leaves, never to the test', (tester) async {
      await pumpPage(tester, FakePlacementRepository());
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(leaves, 1);
    });

    testWidgets('the guide climbs step by step, and the level lands last', (
      tester,
    ) async {
      await pumpPage(tester, FakePlacementRepository(), settle: false);
      double position() => tester
          .widget<LevelLadder>(find.byType(LevelLadder))
          .moment
          .guidePosition;
      await tester.pump();
      expect(position(), 0);

      final timing = PlacementResultEntrance(testResult.levelIndex);
      await tester.pump(
        PlacementResultEntrance.climb + PlacementResultEntrance.hop,
      );
      expect(position(), closeTo(1, .2));

      await tester.pump(timing.settled);
      expect(position(), testResult.levelIndex);
      await tester.pump();
    });

    testWidgets('under reduce motion, everything is simply there', (
      tester,
    ) async {
      final cubit = cubitWith(FakePlacementRepository());
      await tester.pumpLocalized(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: BlocProvider.value(
            value: cubit,
            child: PlacementResultPage(onStart: () {}, onLeave: () {}),
          ),
        ),
      );
      await cubit.load();
      await tester.pump();
      await tester.pump();
      final ladder = tester.widget<LevelLadder>(find.byType(LevelLadder));
      expect(ladder.moment.guidePosition, testResult.levelIndex);
      final bars = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((b) => b.widthFactor);
      expect(bars.first, 1);
    });

    testWidgets('the ladder is left to the text for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, _with(const [Ok(_atA1)]));
      expect(
        tester
            .getSemantics(
              find
                  .ancestor(
                    of: find.text('placement_result_estimated'.tr()),
                    matching: find.byType(ExcludeSemantics),
                  )
                  .first,
            )
            .label,
        contains('placement_result_estimated'.tr()),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
