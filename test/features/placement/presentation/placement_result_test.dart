import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/models/placement_result_model.dart';
import 'package:englizia/features/placement/data/repositories/placement_repository_impl.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';
import 'package:englizia/features/placement/presentation/result/cubit/placement_result_cubit.dart';
import 'package:englizia/features/placement/presentation/result/pages/placement_result_page.dart';
import 'package:englizia/features/placement/presentation/result/widgets/level_ladder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_placement_repository.dart';
import '../../../helpers/pump_app.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

const _atFirst = PlacementResult(
  levels: testLevels,
  levelIndex: 0,
  skills: testSkills,
);

const _atA1 = PlacementResult(
  levels: testLevels,
  levelIndex: 1,
  skills: testSkills,
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

  group('data', () {
    late FakeHttpAdapter adapter;
    late SettingsStorageService settings;
    late FakeResponse Function(RequestOptions) answer;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsStorageService(await SharedPreferences.getInstance());
      answer = (_) => const FakeResponse(200);
      adapter = FakeHttpAdapter((options) => answer(options));
    });

    PlacementRepositoryImpl repository() => PlacementRepositoryImpl(
      PlacementRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      ),
      settings: settings,
    );

    test('every mock result parses, from the panel\'s levels', () async {
      final bundle = _DiskBundle();
      for (final (asset, code) in [
        ('assets/mock/placement/result_a2.json', 'A2'),
        ('assets/mock/placement/result_pre_a1.json', 'Pre-A1'),
        ('assets/mock/placement/result_b2.json', 'B2'),
      ]) {
        final body = jsonDecode(await bundle.loadString(asset));
        final result = PlacementResultModel.fromJson(
          (ApiClient.unwrap(body)! as Map).cast<String, Object?>(),
        ).entity;
        expect(result.levels[result.levelIndex].code, code);
        expect(result.levels, hasLength(5));
        expect(result.levels.first.canDo, hasLength(3));
        expect(result.skills, hasLength(4));
      }
    });

    test('a level outside the ladder is rejected', () {
      expect(
        () => PlacementResultModel.fromJson(const {
          'levelId': 'x',
          'levels': <Object>[],
        }),
        throwsFormatException,
      );
    });

    test('a skill this version doesn\'t know is left out', () {
      final result = PlacementResultModel.fromJson(const {
        'levelId': 'a',
        'levels': [
          {
            'id': 'a',
            'code': 'A1',
            'name': {'ar': 'مبتدئ', 'en': 'Beginner'},
            'canDo': [
              {'ar': 'تقرأ', 'en': 'Read'},
            ],
          },
        ],
        'skills': [
          {'skill': 'speaking', 'score': 1},
          {'skill': 'grammar', 'score': .5},
        ],
      }).entity;
      expect(result.skills.single.kind, PlacementSkillKind.grammar);
      expect(result.levels.single.canDo.single.en, 'Read');
    });

    test('the result: GET, and the attempt is forgotten', () async {
      await settings.setPlacementProgress('{}');
      await settings.setPlacementStatus('{}');
      final body = jsonDecode(
        await _DiskBundle().loadString('assets/mock/placement/result_a2.json'),
      );
      answer = (_) => FakeResponse(200, body: body);

      final result = await repository().getResult('att');
      expect(result, isA<Ok<PlacementResult>>());
      expect(
        adapter.requests.single.path,
        '/api/v1/app/placement/attempts/att/result',
      );
      expect(settings.placementProgress, isNull);
      expect(settings.placementStatus, isNull);
    });

    test('with no connection, what is kept stays', () async {
      await settings.setPlacementProgress('{}');
      answer = (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
      final result = await repository().getResult('att');
      expect((result as Err).failure, isA<NetworkFailure>());
      expect(settings.placementProgress, isNotNull);
    });

    test('accepting: POST with the level', () async {
      expect(await repository().acceptLevel('att', 'a1'), isA<Ok<void>>());
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/app/placement/attempts/att/accept');
      expect(request.data, {'levelId': 'a1'});
    });

    test('mock mode fails once, then walks through the levels', () async {
      final fake = PlacementFakeDataSource(
        _DiskBundle(),
        latency: Duration.zero,
      );
      await expectLater(fake.getResult('att'), throwsException);
      final codes = <String>[];
      for (var i = 0; i < 3; i++) {
        final result = (await fake.getResult('att')).entity;
        codes.add(result.levels[result.levelIndex].code);
      }
      expect(codes, ['A2', 'Pre-A1', 'B2']);
      await fake.acceptLevel('att', 'a');
    });
  });

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
      expect(placement.accepted, ['a1']);
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
      expect(find.text('مبتدئ'), findsOneWidget);
      expect(find.text('placement_result_can'.tr()), findsOneWidget);
      expect(find.text('تسأل أسئلة بسيطة'), findsOneWidget);
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

    testWidgets('the first level: from the beginning, nothing lower', (
      tester,
    ) async {
      await pumpPage(tester, _with(const [Ok(_atFirst)]));
      expect(find.text('placement_result_from_start'.tr()), findsOneWidget);
      expect(find.text('البداية'), findsNothing);
      expect(find.text('placement_result_first_week'.tr()), findsOneWidget);
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
      expect(placement.accepted, ['a2']);
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
