import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/presentation/conversation/cubit/conversation_cubit.dart';
import 'package:englizia/features/talk/presentation/conversation/pages/conversation_page.dart';
import 'package:englizia/features/talk/presentation/conversation/widgets/chat_parts.dart';
import 'package:englizia/features/talk/presentation/talk/cubit/talk_cubit.dart';
import 'package:englizia/features/talk/presentation/talk/pages/talk_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_talk_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

/// Every clip in these tests plays this long.
const _clip = Duration(seconds: 1);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeTalkRepository talk;
  late FakeClipPlayer player;
  late FakeConnectivityService connectivity;

  setUp(() {
    talk = FakeTalkRepository();
    player = FakeClipPlayer(length: _clip);
    connectivity = FakeConnectivityService();
    addTearDown(connectivity.dispose);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(_clip);
    await tester.pump(_clip);
    await tester.pump(const Duration(seconds: 2));
  }

  group('the tab', () {
    TalkCubit cubit() {
      final subject = TalkCubit(talk, connectivity);
      addTearDown(subject.close);
      return subject;
    }

    test(
      'kept scenarios show; with none and no connection, it says so',
      () async {
        final subject = cubit();
        await subject.start();
        expect(subject.state.load, LoadStatus.ready);

        talk
          ..home = null
          ..homeFailure = const NetworkFailure();
        final offline = cubit();
        await offline.start();
        expect(offline.state.load, LoadStatus.failure);
      },
    );

    test('offline nothing opens; today\'s AI conversations used up, '
        'only the written ones do', () async {
      final subject = cubit();
      await subject.start();
      final scenarios = [
        for (final unit in talk.home!.units) ...unit.scenarios,
      ];
      final ai = scenarios.first;
      final written = scenarios.firstWhere((s) => s.kind == TalkKind.written);
      final locked = scenarios.firstWhere((s) => s.locked);
      expect(subject.state.canOpen(ai), isTrue);
      expect(subject.state.canOpen(locked), isFalse);

      connectivity.online = false;
      await Future<void>.delayed(Duration.zero);
      expect(subject.state.canOpen(ai), isFalse);
      expect(subject.state.canOpen(written), isFalse);

      connectivity.online = true;
      talk.home = TalkHome(
        units: talk.home!.units,
        quotaLeft: 0,
        quotaTotal: 3,
      );
      await subject.refresh();
      expect(subject.state.canOpen(ai), isFalse);
      expect(subject.state.canOpen(written), isTrue);
    });

    Future<TalkCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      List<ScenarioCard>? opened,
    }) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: Scaffold(
            body: TalkPage(onOpen: (scenario) async => opened?.add(scenario)),
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await settle(tester);
      return subject;
    }

    testWidgets('the scenarios by unit, with what was done in each', (
      tester,
    ) async {
      await pump(tester);

      expect(
        find.text('talk_quota'.tr(namedArgs: {'left': '2', 'total': '3'})),
        findsOneWidget,
      );
      expect(find.text('الوحدة 3: البيت الجديد'), findsOneWidget);
      expect(find.text('الصندوق القابل للكسر'), findsOneWidget);
      expect(find.text('talk_new'.tr()), findsOneWidget);
      expect(
        find.text('talk_done_of'.tr(namedArgs: {'done': '2', 'total': '3'})),
        findsOneWidget,
      );
      expect(find.text('talk_kind_written'.tr()), findsOneWidget);
      expect(
        find.text('talk_unlocks'.tr(namedArgs: {'unit': '5'})),
        findsOneWidget,
      );
    });

    testWidgets('a scenario opens; a locked one doesn\'t', (tester) async {
      final opened = <ScenarioCard>[];
      await pump(tester, opened: opened);

      await tester.tap(find.text('الصندوق القابل للكسر'));
      await tester.tap(find.text('حجز طاولة'), warnIfMissed: false);
      await settle(tester);

      expect(opened.map((s) => s.id), ['sc_fragile_box']);
    });

    testWidgets('offline, it says so and nothing starts', (tester) async {
      final opened = <ScenarioCard>[];
      connectivity.online = false;
      await pump(tester, opened: opened);

      expect(find.text('talk_offline'.tr()), findsOneWidget);
      await tester.tap(find.text('الصندوق القابل للكسر'));
      await settle(tester);
      expect(opened, isEmpty);
    });

    testWidgets('none left today: the AI ones wait for tomorrow', (
      tester,
    ) async {
      talk.home = TalkHome(
        units: mockTalkHome().units,
        quotaLeft: 0,
        quotaTotal: 3,
      );
      await pump(tester);

      expect(find.text('talk_quota_tomorrow'.tr()), findsNWidgets(2));
    });

    testLayouts('it fits', (tester, layout) async {
      for (final online in [true, false]) {
        connectivity.online = online;
        talk.home = TalkHome(
          units: mockTalkHome().units,
          quotaLeft: online ? 2 : 0,
          quotaTotal: 3,
        );
        await pump(
          tester,
          locale: layout.locale,
          size: layout.size,
          themeMode: layout.themeMode,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('a conversation', () {
    ConversationCubit cubit() {
      final subject = ConversationCubit(
        talk,
        player,
        scenarioId: 'sc_fragile_box',
        introDelay: Duration.zero,
      );
      addTearDown(subject.close);
      return subject;
    }

    /// Lets a line play to its end.
    Future<void> heard() => Future<void>.delayed(_clip * 1.5);

    Future<ConversationCubit> chatting() async {
      final subject = cubit();
      await subject.start();
      await subject.begin();
      await heard();
      return subject;
    }

    test('the intro plays by itself', () async {
      final subject = cubit();
      await subject.start();
      await Future<void>.delayed(Duration.zero);

      expect(subject.state.stage, TalkStage.intro);
      expect(player.loaded, [mockScenario().intro.audioUrl]);
    });

    test('the character opens with its line, then it is the learner\'s '
        'turn', () async {
      final subject = cubit();
      await subject.start();
      await subject.begin();

      expect(subject.state.stage, TalkStage.chat);
      expect(subject.state.messages.single.line, mockScenario().opening);
      expect(subject.state.phase, TalkPhase.speaking);
      expect(subject.state.speaking, isTrue);

      await heard();
      expect(subject.state.phase, TalkPhase.turn);
      expect(subject.state.speaking, isFalse);
    });

    test('a voice that fails leaves the text, and the turn comes', () async {
      player.fails = 9;
      final subject = await chatting();

      expect(subject.state.phase, TalkPhase.turn);
    });

    test('what was heard is a draft: said again, or sent', () async {
      final subject = await chatting();

      subject.heard('Jake, this box is very fragile.');
      expect(subject.state.phase, TalkPhase.draft);
      subject.redo();
      expect(subject.state.phase, TalkPhase.turn);

      subject.heard('Jake, this box is very fragile.');
      final sent = subject.sendDraft();
      expect(subject.state.phase, TalkPhase.thinking);
      await sent;

      expect(talk.said.single, (
        0,
        'Jake, this box is very fragile.',
        SaidVia.mic,
      ));
      expect(subject.state.messages, hasLength(3));
      expect(subject.state.tasksDone, {'t_fragile'});
      expect(subject.state.turnsLeft, 6);
    });

    test('a reply that fails can be asked again, for the same turn', () async {
      talk.failingTurns = 1;
      final subject = await chatting();

      expect(subject.sendTyped('Careful, please!'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(subject.state.phase, TalkPhase.failed);
      expect(subject.state.messages.last.mine, isTrue);

      await subject.retry();

      expect(talk.said.map((s) => s.$1), [0, 0]);
      expect(subject.state.phase, TalkPhase.speaking);
    });

    test('every task done, it ends', () async {
      final subject = await chatting();
      for (var turn = 0; turn < 3; turn++) {
        subject.sendTyped('Line $turn');
        await Future<void>.delayed(Duration.zero);
        await heard();
      }

      expect(subject.state.allDone, isTrue);
      expect(subject.state.phase, TalkPhase.ended);
      expect(subject.sendTyped('One more'), isFalse);
    });

    test('a translation shows and hides', () async {
      final subject = await chatting();

      subject.toggleTranslation(0);
      expect(subject.state.translated, {0});
      subject.toggleTranslation(0);
      expect(subject.state.translated, isEmpty);
    });

    test('it can\'t start: said once, and the intro stays', () async {
      talk.startFailure = const RateLimitFailure();
      final subject = cubit();
      await subject.start();

      await subject.begin();

      expect(subject.state.stage, TalkStage.intro);
      expect(subject.state.startFailure, isA<RateLimitFailure>());
    });

    test('ending tells the server', () async {
      final subject = await chatting();

      subject.end();

      expect(talk.ended, ['conv_1']);
    });

    late FakeSpeechListener listener;

    Future<ConversationCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      VoidCallback? onSummary,
    }) async {
      listener = FakeSpeechListener()..says = 'Jake, this box is very fragile.';
      final subject = cubit();
      final mic = MicCubit(listener, FakeMicPermission());
      addTearDown(mic.close);
      await tester.pumpLocalized(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: subject),
            BlocProvider.value(value: mic),
          ],
          child: ConversationPage(
            onClose: () {},
            onSummary: onSummary ?? () {},
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await settle(tester);
      return subject;
    }

    Future<void> startChat(WidgetTester tester) async {
      await tester.tap(find.text('talk_start'.tr()));
      await settle(tester);
    }

    testWidgets('the intro: who, the role and the tasks', (tester) async {
      await pump(tester);

      expect(find.text('Jake'), findsOneWidget);
      expect(find.text('talk_your_role'.tr()), findsOneWidget);
      for (final task in mockScenario().tasks) {
        expect(find.text(task.text), findsOneWidget);
      }
    });

    testWidgets('spoken, read as a draft, sent: a task is done', (
      tester,
    ) async {
      await pump(tester);
      await startChat(tester);
      expect(find.text(mockScenario().opening.english), findsOneWidget);
      expect(find.text('talk_try_saying'.tr()), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('talk_speak'.tr()));
      await tester.pump();
      listener.finish();
      await tester.pump();

      expect(find.byType(DraftBubble), findsOneWidget);
      await tester.tap(find.text('talk_send'.tr()));
      await tester.pump();

      expect(find.text(mockReplies().first.line.english), findsOneWidget);
      expect(find.byType(TaskPanel), findsOneWidget);
      await settle(tester);
      expect(find.byType(TaskPanel), findsNothing);
    });

    testWidgets('typed instead, and translated', (tester) async {
      await pump(tester);
      await startChat(tester);

      await tester.tap(find.byTooltip('talk_type_instead'.tr()));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Careful, please!');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('talk_send'.tr()));
      await settle(tester);

      expect(talk.said.single.$3, SaidVia.keyboard);
      expect(find.bySemanticsLabel('talk_typed'.tr()), findsOneWidget);

      await tester.tap(find.text('talk_translate'.tr()).first);
      await tester.pump();
      expect(find.text(mockScenario().opening.arabic), findsOneWidget);
    });

    testWidgets('ending asks first, then goes to the summary', (tester) async {
      var summaries = 0;
      await pump(tester, onSummary: () => summaries++);
      await startChat(tester);

      await tester.tap(find.byTooltip('talk_end_label'.tr()));
      await settle(tester);
      await tester.tap(find.text('talk_keep_on'.tr()));
      await settle(tester);
      expect(summaries, 0);

      await tester.tap(find.byTooltip('talk_end_label'.tr()));
      await settle(tester);
      await tester.tap(find.text('talk_end_now'.tr()));
      await settle(tester);

      expect(summaries, 1);
      expect(talk.ended, ['conv_1']);
    });

    testLayouts('every stage fits', (tester, layout) async {
      talk.failingTurns = 1;
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);
      await startChat(tester);
      subject.heard('Jake, this box is very fragile.');
      await settle(tester);
      expect(tester.takeException(), isNull);
      await subject.sendDraft();
      await settle(tester);
      expect(tester.takeException(), isNull);
      await subject.retry();
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (var turn = 1; turn < 3; turn++) {
        await settle(tester);
        subject.sendTyped('Line $turn');
        await tester.pump();
      }
      await settle(tester);
      expect(find.byType(ChatEnded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
