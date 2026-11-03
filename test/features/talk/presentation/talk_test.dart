import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/presentation/conversation/cubit/conversation_cubit.dart';
import 'package:englizia/features/talk/presentation/conversation/pages/conversation_page.dart';
import 'package:englizia/features/talk/presentation/conversation/widgets/chat_parts.dart';
import 'package:englizia/features/talk/presentation/conversation/widgets/summary_view.dart';
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

/// A written conversation's pauses, and the wait before notes are asked again.
const _hold = Duration(milliseconds: 100);

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
        heardHold: _hold,
        replyDelay: _hold,
        notesRetry: _hold,
        notesTries: 2,
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

    test('ending tells the server what was done', () async {
      final subject = await chatting();

      subject.finish();

      expect(talk.ended.single.$1, 'conv_1');
      expect(subject.state.stage, TalkStage.summary);
    });

    Future<ConversationCubit> saidOneLine() async {
      final subject = await chatting();
      subject.sendTyped('Careful, please!');
      await Future<void>.delayed(Duration.zero);
      await heard();
      return subject;
    }

    test('the summary: the notes come once they are made', () async {
      talk.notesAnswers = [
        const Ok(TalkNotes(status: NotesStatus.pending)),
        Ok(mockNotes()),
      ];
      final subject = await saidOneLine();

      subject.finish();
      expect(subject.state.notes!.status, NotesStatus.pending);
      await Future<void>.delayed(_hold * 3);

      expect(subject.state.notes!.status, NotesStatus.ready);
      expect(subject.state.notes!.notes, hasLength(2));
    });

    test('notes that never come, or can\'t be reached, come later', () async {
      talk.notesAnswers = [const Ok(TalkNotes(status: NotesStatus.pending))];
      final waiting = await saidOneLine();
      waiting.finish();
      await Future<void>.delayed(_hold * 4);
      expect(waiting.state.notes!.status, NotesStatus.failed);

      talk.notesAnswers = [const Err(NetworkFailure())];
      final offline = await saidOneLine();
      offline.finish();
      await Future<void>.delayed(Duration.zero);
      expect(offline.state.notes!.status, NotesStatus.failed);
    });

    test('nothing said: no notes to wait for', () async {
      final subject = await chatting();

      subject.finish();

      expect(subject.state.notes, isNull);
      expect(talk.notesAsked, 0);
    });

    test('again: an AI one goes back to its intro', () async {
      final subject = await saidOneLine();
      subject.finish();

      await subject.restart();

      expect(subject.state.stage, TalkStage.intro);
      expect(subject.state.messages, isEmpty);
      expect(subject.state.tasksDone, isEmpty);
    });

    group('written', () {
      setUp(() => talk.scenario = mockWrittenScenario());

      test('repeating: the words heard show, then the sentence goes, and '
          'the character answers', () async {
        final subject = await chatting();
        expect(subject.state.turnsLeft, 3);
        expect(subject.state.scriptTurn, isA<RepeatTurn>());

        subject.heard('how much is this');
        expect(subject.state.phase, TalkPhase.heard);
        expect(subject.state.heard, [true, true, true, true, false]);

        await Future<void>.delayed(_hold * 1.5);
        expect(subject.state.phase, TalkPhase.sent);
        expect(
          subject.state.messages.last.line.english,
          'How much is this bag?',
        );
        expect(subject.state.messages.last.via, SaidVia.mic);

        await Future<void>.delayed(_hold * 1.5);
        expect(subject.state.messages.last.line.english, 'It\'s ten dollars.');
        expect(subject.state.tasksDone, {'t_price'});
        expect(subject.state.turnsLeft, 2);
        expect(talk.said, isEmpty);
        expect(subject.sendTyped('Hi'), isFalse);
      });

      Future<void> next(ConversationCubit subject) async {
        await Future<void>.delayed(_hold * 1.5);
        await heard();
      }

      test('a reply that doesn\'t fit does no task; the script\'s end ends '
          'it', () async {
        final subject = await chatting();
        subject.heard('How much is this bag?');
        await Future<void>.delayed(_hold * 1.5);
        await next(subject);

        subject.choose(1);
        await next(subject);
        expect(subject.state.messages.last.line.english, startsWith('Sorry'));
        expect(subject.state.tasksDone, {'t_price'});

        subject.choose(0);
        await next(subject);
        expect(subject.state.tasksDone, {'t_price', 't_bye'});
        expect(subject.state.phase, TalkPhase.ended);

        subject.finish();
        expect(subject.state.notes, isNull);
        expect(talk.ended.single.$2, {'t_price', 't_bye'});
      });

      test('again: it starts at once', () async {
        final subject = await chatting();
        subject.finish();

        await subject.restart();

        expect(subject.state.stage, TalkStage.chat);
        expect(talk.starts, 2);
      });
    });

    late FakeSpeechListener listener;

    Future<ConversationCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      VoidCallback? onClose,
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
          child: ConversationPage(onClose: onClose ?? () {}),
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

    /// «اعرض المحادثة كاملة» is under the notes.
    Future<void> openFull(WidgetTester tester) async {
      final link = find.text('talk_show_full'.tr());
      await tester.scrollUntilVisible(
        link,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(link);
    }

    String summaryTitle() =>
        'talk_summary_title'.tr(namedArgs: {'name': 'Jake'});

    testWidgets('ending asks first, then the summary', (tester) async {
      await pump(tester);
      await startChat(tester);

      await tester.tap(find.byTooltip('talk_end_label'.tr()));
      await settle(tester);
      await tester.tap(find.text('talk_keep_on'.tr()));
      await settle(tester);
      expect(find.text(summaryTitle()), findsNothing);

      await tester.tap(find.byTooltip('talk_end_label'.tr()));
      await settle(tester);
      await tester.tap(find.text('talk_end_now'.tr()));
      await settle(tester);

      expect(find.text(summaryTitle()), findsOneWidget);
      expect(talk.ended.single.$1, 'conv_1');
    });

    Future<ConversationCubit> summary(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      VoidCallback? onClose,
    }) async {
      final subject = await pump(
        tester,
        locale: locale,
        size: size,
        themeMode: themeMode,
        onClose: onClose,
      );
      await startChat(tester);
      for (final line in [
        'Jake, this box is very fragile, you put it slow.',
        'Can you put it in kitchen?',
      ]) {
        subject.sendTyped(line);
        await settle(tester);
      }
      subject.finish();
      await settle(tester);
      return subject;
    }

    testWidgets('the summary: tasks, better ways to say, and what is left '
        'leads', (tester) async {
      var closed = 0;
      await summary(tester, onClose: () => closed++);

      expect(
        find.text('talk_done_of'.tr(namedArgs: {'done': '2', 'total': '3'})),
        findsOneWidget,
      );
      expect(find.byType(BetterCard), findsNWidgets(2));
      expect(find.text('الصفة والظرف: slow و slowly'), findsOneWidget);
      expect(find.text('talk_added_concepts'.tr()), findsOneWidget);
      final retry = tester.getTopLeft(find.text('talk_retry'.tr()));
      final done = tester.getTopLeft(find.text('talk_finished'.tr()));
      expect(retry.dx, greaterThan(done.dx));

      await tester.tap(find.text('talk_finished'.tr()));
      expect(closed, 1);
    });

    testWidgets('nothing to say better: it says so', (tester) async {
      talk.notesAnswers = [const Ok(TalkNotes(status: NotesStatus.ready))];
      await summary(tester);

      expect(find.text('talk_all_clear'.tr()), findsOneWidget);
      expect(find.text('talk_better'.tr()), findsNothing);
    });

    testWidgets('notes being made, then not made', (tester) async {
      talk.notesAnswers = [const Ok(TalkNotes(status: NotesStatus.pending))];
      final subject = await pump(tester);
      await startChat(tester);
      subject.sendTyped('Careful, please!');
      await settle(tester);
      subject.finish();
      await tester.pump();
      await tester.pump();

      expect(find.text('talk_notes_pending'.tr()), findsOneWidget);
      await settle(tester);
      expect(find.text('talk_notes_later'.tr()), findsOneWidget);
    });

    testWidgets('the whole conversation: a dotted line opens its better form', (
      tester,
    ) async {
      await summary(tester);

      await openFull(tester);
      await settle(tester);
      expect(find.text('talk_full_title'.tr()), findsOneWidget);
      expect(find.text('talk_better_form'.tr()), findsNothing);

      await tester.tap(find.text('Can you put it in kitchen?'));
      await settle(tester);
      expect(find.text('talk_better_form'.tr()), findsOneWidget);

      await tester.tap(find.byTooltip('common_back'.tr()));
      await settle(tester);
      expect(find.text(summaryTitle()), findsOneWidget);
    });

    testWidgets('written: repeat, then choose a reply that flies in', (
      tester,
    ) async {
      talk.scenario = mockWrittenScenario();
      await pump(tester);
      await startChat(tester);
      expect(find.byType(RepeatCard), findsOneWidget);
      expect(find.text('talk_kind_written'.tr()), findsOneWidget);

      listener.says = 'How much is this bag';
      await tester.tap(find.bySemanticsLabel('talk_say_sentence'.tr()));
      await tester.pump();
      listener.finish();
      await tester.pump();
      expect(
        find.text('talk_heard'.plural(5, namedArgs: {'heard': '5'})),
        findsOneWidget,
      );
      await settle(tester);

      expect(find.byType(ChooseCards), findsOneWidget);
      await tester.tap(find.text('I\'ll take it, please.'));
      await tester.pump();
      expect(find.byType(FlyIn), findsOneWidget);
      await settle(tester);
      expect(find.text('Great choice! Here you are.'), findsOneWidget);
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
      await tester.tap(find.text('talk_summary'.tr()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await openFull(tester);
      await settle(tester);
      await tester.tap(find.text('Line 1'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testLayouts('a written conversation and its summary fit', (
      tester,
      layout,
    ) async {
      talk.scenario = mockWrittenScenario();
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      await startChat(tester);
      subject.heard('How much is this');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await settle(tester);
      expect(tester.takeException(), isNull);
      subject.choose(1);
      await settle(tester);
      subject.choose(1);
      await settle(tester);
      expect(find.byType(ChatEnded), findsOneWidget);
      expect(tester.takeException(), isNull);
      subject.finish();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
