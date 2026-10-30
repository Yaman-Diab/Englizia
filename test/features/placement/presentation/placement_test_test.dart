import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/core/design_system/widgets/notice_card.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/repositories/placement_repository_impl.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';
import 'package:englizia/features/placement/presentation/test/cubit/placement_test_cubit.dart';
import 'package:englizia/features/placement/presentation/test/pages/placement_test_page.dart';
import 'package:englizia/features/placement/presentation/test/widgets/stage_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_placement_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

const _toSecond = PlacementNextStage(
  stage: 2,
  questionCount: 15,
  listeningCount: 4,
  deciding: false,
);

const _toDeciding = PlacementNextStage(
  stage: 3,
  questionCount: 8,
  listeningCount: 0,
  deciding: true,
);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeClipPlayer player;

  setUp(() => player = FakeClipPlayer());

  PlacementTestCubit cubitWith(FakePlacementRepository placement) {
    final cubit = PlacementTestCubit(placement, player);
    addTearDown(cubit.close);
    return cubit;
  }

  FakePlacementRepository only(
    List<PlacementQuestion> questions, {
    List<Result<PlacementNextStage?>> completions = const [Ok(null)],
  }) => FakePlacementRepository(
    const [Ok(testPlacementSummary)],
    const [],
    const [Ok(null)],
    const [Ok(testAttempt)],
    [Ok(questions)],
    completions,
  );

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

    FakeResponse data(Map<String, Object?> data) =>
        FakeResponse(200, body: {'statusCode': 200, 'data': data});

    void goOffline() => answer = (options) =>
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );

    const given = PlacementAnswer(
      attemptId: 'att',
      stage: 1,
      questionId: 'q1',
      optionId: 'o1',
      plays: 0,
    );

    test('the attempt: POST attempts', () async {
      answer = (_) => data(const {
        'attemptId': 'att',
        'stageSizes': [12, 15],
        'stage': 1,
        'answered': 8,
      });
      final result = await repository().startAttempt();
      expect(
        (result as Ok<PlacementAttempt>).value,
        const PlacementAttempt(
          id: 'att',
          stageSizes: [12, 15],
          stage: 1,
          answered: 8,
        ),
      );
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/api/v1/app/placement/attempts');
    });

    test('a stage: every kind of question, with no answer key', () async {
      final bundle = _DiskBundle();
      final body = jsonDecode(
        await bundle.loadString(PlacementFakeDataSource.stageAsset(1)),
      );
      answer = (_) => FakeResponse(200, body: body);
      final result = await repository().getStage('att', 1);
      final questions = (result as Ok<List<PlacementQuestion>>).value;
      expect(
        adapter.requests.single.path,
        '/api/v1/app/placement/attempts/att/stages/1',
      );
      expect(questions.map((q) => q.kind), PlacementQuestionKind.values);
      expect(questions.first.before, 'I usually');
      expect(questions[2].passage, isNotEmpty);
      expect(questions[3].maxPlays, 2);
      expect(jsonEncode(body), isNot(contains('correct')));
    });

    test(
      'a question it can\'t show is a failure, not a broken screen',
      () async {
        answer = (_) => data(const {
          'questions': [
            {'id': 'q', 'type': 'speaking', 'options': <Object>[]},
          ],
        });
        final result = await repository().getStage('att', 1);
        expect((result as Err).failure, isA<UnknownFailure>());
      },
    );

    test(
      'an answer is kept, sent once under a stable id, then let go',
      () async {
        await repository().saveAnswer(given);
        await pumpEventQueue();

        final request = adapter.requests.single;
        expect(request.path, '/api/v1/app/placement/attempts/att/answers');
        final sent = request.data! as Map;
        expect(sent['questionId'], 'q1');
        expect(sent['optionId'], 'o1');
        expect(sent['dontKnow'], isFalse);
        expect(sent['answerId'], isNotEmpty);
        expect(sent.containsKey('stage'), isFalse);
        expect(repository().unsentAnswers('att', 1), 0);
      },
    );

    test('«I don\'t know» is sent as such', () async {
      await repository().saveAnswer(
        const PlacementAnswer(
          attemptId: 'att',
          stage: 1,
          questionId: 'q1',
          optionId: null,
          plays: 0,
        ),
      );
      await pumpEventQueue();
      final sent = adapter.requests.single.data! as Map;
      expect(sent['optionId'], isNull);
      expect(sent['dontKnow'], isTrue);
    });

    test('offline an answer stays, under the same id when sent', () async {
      goOffline();
      await repository().saveAnswer(given);
      await pumpEventQueue();
      expect(repository().unsentAnswers('att', 1), 1);
      expect(repository().unsentAnswers('att', 2), 0);
      final id = (adapter.requests.single.data! as Map)['answerId'];

      answer = (_) => const FakeResponse(200);
      adapter.requests.clear();
      await repository().completeStage('att', 1);
      expect((adapter.requests.first.data! as Map)['answerId'], id);
      expect(repository().unsentAnswers('att', 1), 0);
    });

    test(
      'closing a stage sends what is left, then asks what follows',
      () async {
        goOffline();
        final repo = repository();
        await repo.saveAnswer(given);
        await pumpEventQueue();

        answer = (options) => options.path.endsWith('/complete')
            ? data(const {
                'next': {
                  'stage': 2,
                  'questionCount': 15,
                  'listeningCount': 4,
                  'deciding': false,
                },
              })
            : const FakeResponse(200);
        adapter.requests.clear();
        final result = await repo.completeStage('att', 1);
        expect((result as Ok<PlacementNextStage?>).value, _toSecond);
        expect(adapter.requests.map((r) => r.path), [
          '/api/v1/app/placement/attempts/att/answers',
          '/api/v1/app/placement/attempts/att/stages/1/complete',
        ]);
      },
    );

    test('offline, closing a stage fails and keeps the answers', () async {
      goOffline();
      final repo = repository();
      await repo.saveAnswer(given);
      await pumpEventQueue();
      final result = await repo.completeStage('att', 1);
      expect((result as Err).failure, isA<NetworkFailure>());
      expect(repo.unsentAnswers('att', 1), 1);
    });

    test('with no next stage, the test is over', () async {
      answer = (_) => data(const {'next': null});
      final result = await repository().completeStage('att', 3);
      expect((result as Ok<PlacementNextStage?>).value, isNull);
    });

    test('listens are kept per question, and only for that attempt', () async {
      final repo = repository();
      await repo.savePlays('att', 'q4', 1);
      expect(repo.playsUsed('att', 'q4'), 1);
      expect(repo.playsUsed('other', 'q4'), 0);
    });

    test('starting over forgets the answers kept', () async {
      goOffline();
      final repo = repository();
      await repo.saveAnswer(given);
      await pumpEventQueue();

      answer = (_) => const FakeResponse(201);
      await repo.restartTest();
      expect(repo.unsentAnswers('att', 1), 0);
    });

    test('something broken on the phone counts as nothing kept', () async {
      await settings.setPlacementProgress('not json');
      expect(repository().unsentAnswers('att', 1), 0);
    });

    test('mock mode walks through a whole test', () async {
      final fake = PlacementFakeDataSource(
        _DiskBundle(),
        latency: Duration.zero,
      );
      final attempt = (await fake.startAttempt()).entity;
      for (final stage in [1, 2, 3]) {
        expect((await fake.getStage(attempt.id, stage)).questions, isNotEmpty);
      }
      expect((await fake.completeStage(attempt.id, 1)).entity?.stage, 2);
      // The second stage fails once, to show the offline screen.
      await expectLater(fake.completeStage(attempt.id, 2), throwsException);
      final deciding = (await fake.completeStage(attempt.id, 2)).entity;
      expect(deciding?.deciding, isTrue);
      expect((await fake.completeStage(attempt.id, 3)).entity, isNull);
    });
  });

  group('PlacementTestCubit', () {
    test('opens on the first question, with nothing chosen', () async {
      final cubit = cubitWith(FakePlacementRepository());
      await cubit.start();
      expect(cubit.state.view, PlacementView.question);
      expect(cubit.state.question, testVocabulary);
      expect(cubit.state.canGoOn, isFalse);
      expect(cubit.state.stageProgress, 0);
    });

    test('carries on from what the server and the phone have', () async {
      final placement = FakePlacementRepository(
        const [Ok(testPlacementSummary)],
        const [],
        const [Ok(null)],
        const [
          Ok(
            PlacementAttempt(
              id: 'att',
              stageSizes: [3, 2],
              stage: 1,
              answered: 1,
            ),
          ),
        ],
        const [
          Ok([testVocabulary, testGrammar, testReading]),
        ],
      )..unsent = 1;
      final cubit = cubitWith(placement);
      await cubit.start();
      expect(cubit.state.index, 2);
      expect(cubit.state.question, testReading);
    });

    test('everything answered: only closing the stage was left', () async {
      final placement = FakePlacementRepository()..unsent = 2;
      final cubit = cubitWith(placement);
      await cubit.start();
      expect(placement.completed, [1]);
      expect(cubit.state.finished, isTrue);
    });

    test('a failure to open leaves a retry', () async {
      final placement = FakePlacementRepository(
        const [Ok(testPlacementSummary)],
        const [],
        const [Ok(null)],
        const [Err(NetworkFailure()), Ok(testAttempt)],
      );
      final cubit = cubitWith(placement);
      await cubit.start();
      expect(cubit.state.view, PlacementView.failed);
      await cubit.start();
      expect(cubit.state.view, PlacementView.question);
    });

    test('«I don\'t know» and an option cancel each other', () async {
      final cubit = cubitWith(FakePlacementRepository());
      await cubit.start();
      cubit.choose('o1');
      expect(cubit.state.canGoOn, isTrue);

      cubit.chooseDontKnow();
      expect(cubit.state.optionId, isNull);
      expect(cubit.state.dontKnow, isTrue);
      expect(cubit.state.canGoOn, isTrue);

      cubit.choose('o2');
      expect(cubit.state.dontKnow, isFalse);
      expect(cubit.state.optionId, 'o2');
    });

    test('next keeps the answer and clears the choice', () async {
      final placement = FakePlacementRepository();
      final cubit = cubitWith(placement);
      await cubit.start();
      cubit.choose('o1');
      await cubit.next();

      expect(placement.answers.single.questionId, 'q1');
      expect(placement.answers.single.optionId, 'o1');
      expect(cubit.state.index, 1);
      expect(cubit.state.canGoOn, isFalse);
      expect(cubit.state.stageProgress, .5);
    });

    test('nothing chosen, nothing moves', () async {
      final placement = FakePlacementRepository();
      final cubit = cubitWith(placement);
      await cubit.start();
      await cubit.next();
      expect(placement.answers, isEmpty);
      expect(cubit.state.index, 0);
    });

    test('a stage\'s end says what follows', () async {
      final cubit = cubitWith(
        only(const [testVocabulary], completions: const [Ok(_toSecond)]),
      );
      await cubit.start();
      cubit.chooseDontKnow();
      await cubit.next();
      expect(cubit.state.view, PlacementView.between);
      expect(cubit.state.next, _toSecond);
      expect(cubit.state.stageProgress, 1);
      expect(cubit.state.stageSizes, [2, 15]);
    });

    test('a deciding stage joins the bar', () async {
      final cubit = cubitWith(
        only(const [testVocabulary], completions: const [Ok(_toDeciding)]),
      );
      await cubit.start();
      cubit.chooseDontKnow();
      await cubit.next();
      expect(cubit.state.view, PlacementView.deciding);
      expect(cubit.state.stageSizes, [2, 2, 8]);
    });

    test('going on opens the next stage from its start', () async {
      final placement = FakePlacementRepository(
        const [Ok(testPlacementSummary)],
        const [],
        const [Ok(null)],
        const [Ok(testAttempt)],
        const [
          Ok([testVocabulary]),
          Ok([testGrammar, testReading]),
        ],
        const [Ok(_toSecond)],
      );
      final cubit = cubitWith(placement);
      await cubit.start();
      cubit.chooseDontKnow();
      await cubit.next();
      await cubit.goOn();

      expect(placement.stageCalls, [1, 2]);
      expect(cubit.state.stage, 2);
      expect(cubit.state.index, 0);
      expect(cubit.state.question, testGrammar);
    });

    test('the last stage closed: the test is over', () async {
      final cubit = cubitWith(only(const [testVocabulary]));
      await cubit.start();
      cubit.chooseDontKnow();
      await cubit.next();
      expect(cubit.state.finished, isTrue);
    });

    test('a stage ending offline waits, and sends each answer once', () async {
      final placement = only(
        const [testVocabulary],
        completions: const [Err(NetworkFailure()), Ok(_toSecond)],
      );
      final cubit = cubitWith(placement);
      await cubit.start();
      cubit.chooseDontKnow();
      await cubit.next();
      expect(cubit.state.view, PlacementView.offline);

      await cubit.goOn();
      expect(cubit.state.view, PlacementView.between);
      expect(placement.answers, hasLength(1));
      expect(placement.completed, [1, 1]);
    });

    test('another failure stays on the question, and retries once', () async {
      final placement = only(
        const [testVocabulary],
        completions: const [Err(ServerFailure()), Ok(null)],
      );
      final cubit = cubitWith(placement);
      await cubit.start();
      cubit.chooseDontKnow();
      await cubit.next();
      expect(cubit.state.actionFailure, isA<ServerFailure>());
      expect(cubit.state.view, PlacementView.question);

      await cubit.retry();
      expect(cubit.state.finished, isTrue);
      expect(placement.answers, hasLength(1));
    });

    group('the clip', () {
      test('listens run out, each one counted and kept', () async {
        final placement = only(const [testListening]);
        final cubit = cubitWith(placement);
        await cubit.start();
        expect(cubit.state.playsLeft, 2);

        await cubit.togglePlay();
        expect(cubit.state.audio, PlacementAudio.playing);
        expect(player.played, 1);
        await cubit.togglePlay();
        expect(cubit.state.audio, PlacementAudio.idle);
        expect(cubit.state.playsLeft, 1);
        expect(placement.plays['q4'], 1);
        expect(player.stopped, 1);

        await cubit.togglePlay();
        await cubit.togglePlay();
        expect(cubit.state.playsLeft, 0);

        await cubit.togglePlay();
        expect(cubit.state.audio, PlacementAudio.idle);
        expect(player.played, 2);
      });

      test('it ends by itself', () async {
        player = FakeClipPlayer(length: const Duration(milliseconds: 1));
        final cubit = cubitWith(only(const [testListening]));
        await cubit.start();
        await cubit.togglePlay();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(cubit.state.audio, PlacementAudio.idle);
        expect(cubit.state.playsLeft, 1);
      });

      test('a failure doesn\'t use up a listen, and can be retried', () async {
        player = FakeClipPlayer(fails: 1);
        final cubit = cubitWith(only(const [testListening]));
        await cubit.start();
        await cubit.togglePlay();
        expect(cubit.state.audio, PlacementAudio.failed);
        expect(cubit.state.playsLeft, 2);

        await cubit.togglePlay();
        expect(cubit.state.audio, PlacementAudio.playing);
        await cubit.togglePlay();
      });

      test('the stop sheet cuts it off, and it counts', () async {
        final cubit = cubitWith(only(const [testListening]));
        await cubit.start();
        await cubit.togglePlay();
        await cubit.interrupt();
        expect(cubit.state.audio, PlacementAudio.idle);
        expect(cubit.state.playsLeft, 1);
      });

      test('moving on stops it, and doesn\'t count again', () async {
        final placement = only(const [testListening, testVocabulary]);
        final cubit = cubitWith(placement);
        await cubit.start();
        await cubit.togglePlay();
        cubit.chooseDontKnow();
        await cubit.next();
        expect(player.stopped, 1);
        expect(placement.answers.single.plays, 0);
        expect(cubit.state.audio, PlacementAudio.idle);
      });

      test('listens used before stopping stay used', () async {
        final placement = only(const [testListening]);
        placement.plays['q4'] = 2;
        final cubit = cubitWith(placement);
        await cubit.start();
        expect(cubit.state.playsLeft, 0);
      });

      test('a clip still loading can\'t play on the next question', () async {
        final loading = Completer<Duration?>();
        final slow = _SlowClipPlayer(loading);
        final placement = only(const [testListening, testVocabulary]);
        final cubit = PlacementTestCubit(placement, slow);
        addTearDown(cubit.close);
        await cubit.start();
        unawaited(cubit.togglePlay());
        await pumpEventQueue();
        cubit.chooseDontKnow();
        await cubit.next();

        loading.complete(const Duration(seconds: 1));
        await pumpEventQueue();
        expect(cubit.state.audio, PlacementAudio.idle);
        expect(slow.played, 0);
      });
    });
  });

  group('PlacementTestPage', () {
    late int stops;
    late int finishes;

    setUp(() {
      stops = 0;
      finishes = 0;
    });

    Future<PlacementTestCubit> pumpPage(
      WidgetTester tester,
      FakePlacementRepository placement, {
      LayoutCase? layout,
      Size? size,
    }) async {
      final cubit = cubitWith(placement);
      await cubit.start();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementTestPage(
            onStop: () => stops++,
            onFinished: (_) => finishes++,
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: size ?? layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.pump(const Duration(seconds: 1));
      return cubit;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.stepOut);
      await tester.pump();
      await tester.pump(AppMotion.slow * 2);
    }

    AppButton button(WidgetTester tester) =>
        tester.widget<AppButton>(find.byType(AppButton));

    for (final (name, question) in const <(String, PlacementQuestion)>[
      ('vocabulary', testVocabulary),
      ('grammar', testGrammar),
      ('reading', testReading),
      ('listening', testListening),
    ]) {
      testLayouts('$name lays out without overflow', (tester, layout) async {
        await pumpPage(tester, only([question]), layout: layout);
        expect(tester.takeException(), isNull);
      });
    }

    testLayouts('a stage\'s end lays out without overflow', (
      tester,
      layout,
    ) async {
      final cubit = await pumpPage(
        tester,
        only(const [testVocabulary], completions: const [Ok(_toSecond)]),
        layout: layout,
      );
      cubit.chooseDontKnow();
      await cubit.next();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testLayouts('offline lays out without overflow', (tester, layout) async {
      final cubit = await pumpPage(
        tester,
        only(
          const [testVocabulary],
          completions: const [Err(NetworkFailure())],
        ),
        layout: layout,
      );
      cubit.chooseDontKnow();
      await cubit.next();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a question: where it is, its parts, and no way on yet', (
      tester,
    ) async {
      await pumpPage(tester, FakePlacementRepository());
      expect(find.text('placement_stage_1'.tr()), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('placement_q_vocabulary'.tr()), findsOneWidget);
      expect(find.text('have'), findsOneWidget);
      expect(find.text('placement_dont_know'.tr()), findsOneWidget);
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('choosing marks one choice, in blue only, and allows next', (
      tester,
    ) async {
      await pumpPage(tester, FakePlacementRepository());
      await tester.tap(find.text('have'));
      await tester.pump();
      List<bool> marks() => tester
          .widgetList<ChoiceSurface>(find.byType(ChoiceSurface))
          .map((c) => c.selected)
          .toList();
      expect(marks(), [true, false, false]);
      expect(button(tester).onPressed, isNotNull);

      await tester.tap(find.text('placement_dont_know'.tr()));
      await tester.pump();
      expect(marks(), [false, false, true]);
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('next moves on, out and then in, with its bar', (tester) async {
      final placement = FakePlacementRepository();
      await pumpPage(tester, placement);
      await tester.tap(find.text('have'));
      await tester.pump();
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      // The old question is still leaving.
      expect(find.text('placement_q_vocabulary'.tr()), findsOneWidget);

      await settle(tester);
      expect(find.text('placement_q_grammar'.tr()), findsOneWidget);
      expect(find.text('placement_q_vocabulary'.tr()), findsNothing);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(tester.widget<StageBar>(find.byType(StageBar)).progress, .5);
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('under reduce motion, the steps only fade', (tester) async {
      final cubit = cubitWith(FakePlacementRepository());
      await cubit.start();
      await tester.pumpLocalized(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: BlocProvider.value(
            value: cubit,
            child: PlacementTestPage(onStop: () {}, onFinished: (_) {}),
          ),
        ),
      );
      await tester.pump();
      cubit.chooseDontKnow();
      await cubit.next();
      await settle(tester);
      expect(find.text('placement_q_grammar'.tr()), findsOneWidget);
    });

    testWidgets('the reading text fades until its end is reached', (
      tester,
    ) async {
      const long = PlacementQuestion(
        id: 'long',
        kind: PlacementQuestionKind.reading,
        passage:
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. '
            'Omar works at a bank in the city centre. ',
        ask: 'Where does Omar work?',
        options: testOptions,
      );
      await pumpPage(tester, only(const [long]));
      final passage = find.textContaining('Omar works');
      expect(passage, findsOneWidget);
      expect(find.text('Where does Omar work?'), findsOneWidget);

      // The inner text scrolls by itself, and the page doesn't move.
      final scrollables = find.byType(Scrollable);
      expect(scrollables, findsNWidgets(2));
      await tester.dragFrom(
        tester.getCenter(scrollables.last),
        const Offset(0, -2000),
      );
      await tester.pump();
      final inner = tester.state<ScrollableState>(scrollables.last);
      expect(inner.position.extentAfter, 0);
      final page = tester.state<ScrollableState>(scrollables.first);
      expect(page.position.pixels, 0);
    });

    group('listening', () {
      testWidgets('shows what is left, in words, and plays', (tester) async {
        final cubit = await pumpPage(tester, only(const [testListening]));
        expect(find.text('placement_plays_left'.plural(2)), findsOneWidget);

        await tester.tap(find.byTooltip('placement_play'.tr()));
        await tester.pump();
        await tester.pump();
        expect(cubit.state.audio, PlacementAudio.playing);
        expect(find.byTooltip('placement_play_stop'.tr()), findsOneWidget);

        await tester.pump(const Duration(seconds: 5));
        await tester.pump(AppMotion.slow);
        expect(find.text('placement_plays_left'.plural(1)), findsOneWidget);
      });

      testWidgets('used up: says so, and the button stays shut', (
        tester,
      ) async {
        final placement = only(const [testListening]);
        placement.plays['q4'] = 2;
        await pumpPage(tester, placement);
        expect(find.text('placement_plays_done'.plural(2)), findsOneWidget);
        final play = tester.widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.play_arrow_rounded),
            matching: find.byType(IconButton),
          ),
        );
        expect(play.onPressed, isNull);
      });

      testWidgets('a failure says so, with a retry', (tester) async {
        player = FakeClipPlayer(fails: 1);
        final cubit = await pumpPage(tester, only(const [testListening]));
        await tester.tap(find.byTooltip('placement_play'.tr()));
        await tester.pump();
        await tester.pump();
        expect(find.text('placement_audio_failed'.tr()), findsOneWidget);
        expect(cubit.state.playsLeft, 2);

        await tester.tap(find.text('common_retry'.tr()));
        await tester.pump();
        await tester.pump();
        expect(find.byTooltip('placement_play_stop'.tr()), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(AppMotion.slow);
      });

      testWidgets('waiting for a clip shows the app\'s one spinner', (
        tester,
      ) async {
        final loading = Completer<Duration?>();
        final cubit = PlacementTestCubit(
          only(const [testListening]),
          _SlowClipPlayer(loading),
        );
        addTearDown(cubit.close);
        await cubit.start();
        await tester.pumpLocalized(
          BlocProvider.value(
            value: cubit,
            child: PlacementTestPage(onStop: () {}, onFinished: (_) {}),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byTooltip('placement_play'.tr()));
        await tester.pump();
        expect(find.byType(AppSpinner), findsOneWidget);
        loading.complete(null);
        await tester.pump();
        await tester.pump();
      });
    });

    group('stopping', () {
      Future<void> openSheet(WidgetTester tester) async {
        await tester.tap(find.byTooltip('placement_stop'.tr()));
        await tester.pump();
        await tester.pump();
        await tester.pump(AppMotion.slow);
      }

      testWidgets('close asks first; staying is the main way', (tester) async {
        await pumpPage(tester, FakePlacementRepository());
        await openSheet(tester);
        expect(find.byType(ActionSheet), findsOneWidget);
        expect(find.text('placement_stop_title'.tr()), findsOneWidget);
        expect(find.text('placement_stop_body'.tr()), findsOneWidget);

        await tester.tap(find.text('placement_continue'.tr()));
        await tester.pump();
        await tester.pump(AppMotion.slow);
        expect(find.byType(ActionSheet), findsNothing);
        expect(stops, 0);
      });

      testWidgets('stopping now leaves', (tester) async {
        await pumpPage(tester, FakePlacementRepository());
        await openSheet(tester);
        await tester.tap(find.text('placement_stop_now'.tr()));
        await tester.pump();
        await tester.pump(AppMotion.slow);
        expect(stops, 1);
      });

      testWidgets('the system\'s back asks too', (tester) async {
        await pumpPage(tester, FakePlacementRepository());
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump();
        await tester.pump(AppMotion.slow);
        expect(find.byType(ActionSheet), findsOneWidget);
        expect(stops, 0);
      });

      testWidgets('opening it cuts the clip off, which counts', (tester) async {
        final cubit = await pumpPage(tester, only(const [testListening]));
        await tester.tap(find.byTooltip('placement_play'.tr()));
        await tester.pump();
        await tester.pump();
        await openSheet(tester);
        expect(cubit.state.audio, PlacementAudio.idle);
        expect(cubit.state.playsLeft, 1);
      });
    });

    group('between stages', () {
      testWidgets('the guide cheers on, says what follows, shows no score', (
        tester,
      ) async {
        final cubit = await pumpPage(
          tester,
          only(const [testVocabulary], completions: const [Ok(_toSecond)]),
        );
        cubit.chooseDontKnow();
        await cubit.next();
        await settle(tester);

        final guide = tester.widget<Mascot>(find.byType(Mascot));
        expect(guide.expression, MascotExpression.encourage);
        expect(find.text('placement_finished_stage_1'.tr()), findsOneWidget);
        expect(find.textContaining('15'), findsOneWidget);
        expect(find.text('placement_go_on'.tr()), findsOneWidget);
        expect(tester.widget<StageBar>(find.byType(StageBar)).progress, 1);
      });

      testWidgets('the deciding stage says few questions are left', (
        tester,
      ) async {
        final cubit = await pumpPage(
          tester,
          only(const [testVocabulary], completions: const [Ok(_toDeciding)]),
        );
        cubit.chooseDontKnow();
        await cubit.next();
        await settle(tester);

        expect(find.text('placement_deciding_title'.tr()), findsOneWidget);
        expect(find.text('placement_deciding_body'.plural(8)), findsOneWidget);
        expect(tester.widget<StageBar>(find.byType(StageBar)).sizes, [2, 2, 8]);
      });

      testWidgets('offline: no blame, and a retry that sends and moves on', (
        tester,
      ) async {
        final cubit = await pumpPage(
          tester,
          only(
            const [testVocabulary],
            completions: const [Err(NetworkFailure()), Ok(_toSecond)],
          ),
        );
        cubit.chooseDontKnow();
        await cubit.next();
        await settle(tester);

        final guide = tester.widget<Mascot>(find.byType(Mascot));
        expect(guide.expression, MascotExpression.understand);
        expect(find.text('placement_offline_title'.tr()), findsOneWidget);
        expect(find.byType(NoticeCard), findsOneWidget);
        expect(find.text('placement_offline_next'.tr()), findsOneWidget);

        await tester.tap(find.text('common_retry'.tr()));
        await settle(tester);
        expect(find.text('placement_finished_stage_1'.tr()), findsOneWidget);
        expect(find.byType(NoticeCard), findsNothing);
      });

      testWidgets('the test\'s end moves on to the result', (tester) async {
        final cubit = await pumpPage(tester, only(const [testVocabulary]));
        cubit.chooseDontKnow();
        await cubit.next();
        await tester.pump();
        expect(finishes, 1);
      });
    });

    testWidgets('a failed opening offers a retry', (tester) async {
      await pumpPage(
        tester,
        FakePlacementRepository(
          const [Ok(testPlacementSummary)],
          const [],
          const [Ok(null)],
          const [Err(ServerFailure()), Ok(testAttempt)],
        ),
      );
      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(find.text('placement_q_vocabulary'.tr()), findsOneWidget);
    });

    testWidgets('choices and buttons meet the tap target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, only(const [testListening]));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}

/// A clip that takes as long as the test says.
class _SlowClipPlayer extends FakeClipPlayer {
  _SlowClipPlayer(this.loading);

  final Completer<Duration?> loading;

  @override
  Future<Duration?> load(String url) => loading.future;
}
