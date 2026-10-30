import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/pages/exercise_page.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/answer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

/// A player whose load only finishes when told to.
class _SlowLoadPlayer extends FakeClipPlayer {
  final gate = Completer<void>();

  @override
  Future<Duration?> load(String url) async {
    await gate.future;
    return super.load(url);
  }
}

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;
  late FakeClipPlayer player;
  late FakeConnectivityService connectivity;

  setUp(() {
    lessons = FakeLessonRepository();
    player = FakeClipPlayer();
    connectivity = FakeConnectivityService();
  });

  ExerciseCubit cubit() =>
      ExerciseCubit(lessons, player, connectivity, lessonId: 'les');

  /// Answers and moves on until question [index].
  Future<void> advanceTo(ExerciseCubit cubit, int index) async {
    while (cubit.state.index < index) {
      cubit.select(cubit.state.question!.options.first.id);
      await cubit.check();
      await cubit.next();
    }
  }

  group('ExerciseCubit', () {
    test('starts on the first question, ready to answer', () async {
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.ready);
      expect(subject.state.index, 0);
      expect(subject.state.canCheck, isFalse);
      expect(subject.state.done, 0);
      await subject.close();
    });

    test('a failed load offers a retry that recovers', () async {
      lessons.failure = const NetworkFailure();
      final subject = cubit();
      await subject.start();
      expect(subject.state.load, LoadStatus.failure);
      expect(subject.state.failure, isA<NetworkFailure>());

      lessons.failure = null;
      await subject.start();
      expect(subject.state.load, LoadStatus.ready);
      expect(subject.state.failure, isNull);
      await subject.close();
    });

    test(
      'carries on from the question it was left on, hints included',
      () async {
        lessons.saved['les'] = const ExerciseProgress(
          position: 1,
          hinted: {'q1'},
        );
        final subject = cubit();
        await subject.start();

        expect(subject.state.index, 1);
        expect(subject.state.hinted, {'q1'});
        expect(subject.state.done, 1);
        await subject.close();
      },
    );

    test('a lesson with nothing left finishes', () async {
      lessons.exercises = [];
      final subject = cubit();
      await subject.start();

      expect(subject.state.finished, isTrue);
      await subject.close();
    });

    test('selecting enables checking; another choice replaces it', () async {
      final subject = cubit();
      await subject.start();

      subject.select('o1');
      expect(subject.state.canCheck, isTrue);
      subject.select('o2');
      expect(subject.state.selected?.text, 'goes');
      await subject.close();
    });

    test('checking saves the answer once and locks the options', () async {
      final subject = cubit();
      await subject.start();
      subject.select('o2');

      await subject.check();
      await subject.check();
      subject.select('o1');

      expect(subject.state.checked, isTrue);
      expect(subject.state.selectedId, 'o2');
      expect(lessons.answers, const [
        ExerciseAnswer(
          lessonId: 'les',
          questionId: 'q1',
          optionId: 'o2',
          hinted: false,
        ),
      ]);
      await subject.close();
    });

    test('nothing chosen, nothing checked', () async {
      final subject = cubit();
      await subject.start();

      await subject.check();

      expect(subject.state.checked, isFalse);
      expect(lessons.answers, isEmpty);
      await subject.close();
    });

    test('leaving after checking returns to the next question', () async {
      final subject = cubit();
      await subject.start();
      subject.select('o2');
      await subject.check();

      expect(lessons.saved['les']?.position, 1);
      await subject.close();
    });

    test(
      'an opened hint makes the answer assisted, even once closed',
      () async {
        final subject = cubit();
        await subject.start();

        await subject.toggleHint();
        expect(subject.state.hintOpen, isTrue);
        expect(subject.state.hintUsed, isTrue);
        expect(lessons.saved['les']?.hinted, {'q1'});

        await subject.toggleHint();
        expect(subject.state.hintOpen, isFalse);
        expect(subject.state.hintUsed, isTrue);

        subject.select('o2');
        await subject.check();
        expect(lessons.answers.single.hinted, isTrue);
        await subject.close();
      },
    );

    test('a question with no hint ignores the button', () async {
      final subject = cubit();
      await subject.start();
      await advanceTo(subject, 1);

      await subject.toggleHint();

      expect(subject.state.hintOpen, isFalse);
      expect(subject.state.hintUsed, isFalse);
      await subject.close();
    });

    test('the next question starts clean', () async {
      final subject = cubit();
      await subject.start();
      await subject.toggleHint();
      subject.select('o2');
      await subject.check();

      await subject.next();

      expect(subject.state.index, 1);
      expect(subject.state.done, 1);
      expect(subject.state.selectedId, isNull);
      expect(subject.state.checked, isFalse);
      expect(subject.state.hintOpen, isFalse);
      await subject.close();
    });

    test('moving on needs a checked answer', () async {
      final subject = cubit();
      await subject.start();
      subject.select('o2');

      await subject.next();

      expect(subject.state.index, 0);
      await subject.close();
    });

    test('the last question finishes and forgets the place', () async {
      final subject = cubit();
      await subject.start();
      await advanceTo(subject, 3);
      subject.select('o1');
      await subject.check();

      await subject.next();

      expect(subject.state.finished, isTrue);
      expect(subject.state.done, 4);
      expect(lessons.cleared, 1);
      expect(lessons.answers, hasLength(4));
      await subject.close();
    });

    group('audio', () {
      test('a listening question plays once by itself', () async {
        final subject = cubit();
        await subject.start();
        expect(player.played, 0);

        await advanceTo(subject, 2);
        await pumpEventQueue();

        expect(subject.state.audio, ExerciseAudio.playing);
        expect(player.played, 1);
        expect(player.lastSpeed, 1);
        expect(subject.state.clipLength, player.length);
        await subject.close();
      });

      test('a failure leaves the options open, and a retry plays', () async {
        player.fails = 1;
        final subject = cubit();
        await subject.start();
        await advanceTo(subject, 2);
        await pumpEventQueue();
        expect(subject.state.audio, ExerciseAudio.failed);

        subject.select('o1');
        expect(subject.state.canCheck, isTrue);

        await subject.togglePlay();
        expect(subject.state.audio, ExerciseAudio.playing);
        await subject.close();
      });

      test('slower is the same file at 0.75, and takes longer', () async {
        final subject = cubit();
        await subject.start();
        await advanceTo(subject, 2);
        await pumpEventQueue();

        await subject.playSlow();

        expect(player.lastSpeed, ExerciseCubit.slowSpeed);
        expect(subject.state.slow, isTrue);
        expect(
          subject.state.clipLength.inMilliseconds,
          (player.length.inMilliseconds / .75).round(),
        );
        expect(player.loaded.toSet(), hasLength(1));
        await subject.close();
      });

      test('the big button stops what plays', () async {
        final subject = cubit();
        await subject.start();
        await advanceTo(subject, 2);
        await pumpEventQueue();

        await subject.togglePlay();

        expect(subject.state.audio, ExerciseAudio.idle);
        expect(player.stopped, 1);
        await subject.close();
      });

      test('a clip stopped while loading never plays', () async {
        final slow = player = _SlowLoadPlayer();
        final subject = cubit();
        await subject.start();
        await advanceTo(subject, 2);
        await pumpEventQueue();
        expect(subject.state.audio, ExerciseAudio.loading);

        await subject.stopAudio();
        slow.gate.complete();
        await pumpEventQueue();

        expect(subject.state.audio, ExerciseAudio.idle);
        expect(slow.played, 0);
        await subject.close();
      });

      test('checking stops the clip', () async {
        final subject = cubit();
        await subject.start();
        await advanceTo(subject, 2);
        await pumpEventQueue();
        subject.select('o1');

        await subject.check();

        expect(subject.state.audio, ExerciseAudio.idle);
        expect(player.stopped, 1);
        await subject.close();
      });

      test('a word that fails goes quiet, with no failure', () async {
        player.fails = 1;
        final subject = cubit();
        await subject.start();
        await advanceTo(subject, 1);

        await subject.togglePlay();

        expect(subject.state.audio, ExerciseAudio.idle);
        await subject.close();
      });

      test('closing stops the clip', () async {
        final subject = cubit();
        await subject.start();
        await advanceTo(subject, 2);
        await pumpEventQueue();

        await subject.close();

        expect(player.stopped, 1);
      });
    });

    group('the connection', () {
      test('offline, checking still works and keeps the answer', () async {
        connectivity = FakeConnectivityService(online: false);
        final subject = cubit();
        await subject.start();
        expect(subject.state.online, isFalse);
        expect(lessons.sends, 0);

        subject.select('o2');
        await subject.check();

        expect(subject.state.checked, isTrue);
        expect(lessons.answers, hasLength(1));
        await subject.close();
      });

      test('what was kept is sent on opening and on reconnecting', () async {
        final subject = cubit();
        await subject.start();
        expect(lessons.sends, 1);

        connectivity.online = false;
        await pumpEventQueue();
        expect(subject.state.online, isFalse);

        connectivity.online = true;
        await pumpEventQueue();
        expect(subject.state.online, isTrue);
        expect(lessons.sends, 2);
        await subject.close();
      });
    });
  });

  group('ExercisePage', () {
    Future<ExerciseCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      VoidCallback? onExit,
      VoidCallback? onFinished,
    }) async {
      final subject = cubit();
      addTearDown(subject.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: ExercisePage(
            onExit: onExit ?? () {},
            onFinished: onFinished ?? () {},
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await tester.settleEntrance(const Duration(seconds: 1));
      return subject;
    }

    Future<void> leaveClean(WidgetTester tester, ExerciseCubit subject) async {
      await subject.stopAudio();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> moveTo(
      WidgetTester tester,
      ExerciseCubit subject,
      int index,
    ) async {
      await advanceTo(subject, index);
      await tester.settleEntrance(const Duration(seconds: 1));
    }

    AppButton cta(WidgetTester tester) =>
        tester.widget<AppButton>(find.byType(AppButton));

    testLayouts('every state fits', (tester, layout) async {
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);

      await subject.toggleHint();
      subject.select('o2');
      await tester.settleEntrance(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      await subject.check();
      await tester.settleEntrance(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      await subject.next();
      subject.select('o1');
      await tester.settleEntrance(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      await moveTo(tester, subject, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(subject.state.audio, ExerciseAudio.playing);
      expect(tester.takeException(), isNull);

      await moveTo(tester, subject, 3);
      subject.select('o1');
      connectivity.online = false;
      await tester.settleEntrance(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      await leaveClean(tester, subject);
    });

    testWidgets('waits with the one spinner', (tester) async {
      final subject = cubit();
      addTearDown(subject.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: ExercisePage(onExit: () {}, onFinished: () {}),
        ),
      );
      await tester.pump();

      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
      await leaveClean(tester, subject);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      lessons.failure = const NetworkFailure();
      final subject = await pump(tester);

      expect(find.text('common_retry'.tr()), findsOneWidget);

      lessons.failure = null;
      await tester.tap(find.text('common_retry'.tr()));
      await tester.settleEntrance(const Duration(seconds: 1));

      expect(find.text('go'), findsOneWidget);
      await leaveClean(tester, subject);
    });

    testWidgets('the check waits for a choice, and the word fills the blank', (
      tester,
    ) async {
      final subject = await pump(tester);
      expect(cta(tester).onPressed, isNull);
      // Only on its card, until it is chosen.
      expect(find.textContaining('goes'), findsOneWidget);

      await tester.tap(find.text('goes'));
      await tester.settleEntrance(const Duration(seconds: 1));

      expect(subject.state.selectedId, 'o2');
      expect(cta(tester).onPressed, isNotNull);
      expect(find.textContaining('She goes to school'), findsOneWidget);
      await leaveClean(tester, subject);
    });

    testWidgets('a chosen word sits against the punctuation after it', (
      tester,
    ) async {
      final subject = await pump(tester);
      await moveTo(tester, subject, 3);
      await tester.tap(find.text('where post office'));
      await tester.settleEntrance(const Duration(seconds: 1));

      expect(find.textContaining('where post office?'), findsOneWidget);
      await leaveClean(tester, subject);
    });

    testWidgets('selecting gives a light haptic', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final subject = await pump(tester);

      await tester.tap(find.text('goes'));
      await tester.pump();

      expect(calls, ['HapticFeedbackType.selectionClick']);
      await leaveClean(tester, subject);
    });

    testWidgets('the hint opens under the instruction and stays used', (
      tester,
    ) async {
      final subject = await pump(tester);
      expect(find.textContaining('she'), findsNothing);

      await tester.tap(find.byTooltip('lesson_hint_show'.tr()));
      await tester.settleEntrance(const Duration(seconds: 1));
      expect(find.textContaining('she'), findsOneWidget);
      expect(find.byTooltip('lesson_hint_hide'.tr()), findsOneWidget);

      await tester.tap(find.byTooltip('lesson_hint_hide'.tr()));
      await tester.settleEntrance(const Duration(seconds: 1));
      expect(find.textContaining('she'), findsNothing);
      expect(subject.state.hintUsed, isTrue);
      await leaveClean(tester, subject);
    });

    testWidgets('with no hint the button is gone, its space kept', (
      tester,
    ) async {
      final subject = await pump(tester);
      final semantics = tester.ensureSemantics();
      final bar = find.bySemanticsLabel('lesson_progress'.tr());
      final width = tester.getSize(bar).width;

      await moveTo(tester, subject, 1);

      final hint = tester.widget<Visibility>(find.byType(Visibility));
      expect(hint.visible, isFalse);
      expect(hint.maintainSize, isTrue);
      expect(tester.getSize(bar).width, width);
      semantics.dispose();
      await leaveClean(tester, subject);
    });

    testWidgets('pictures have names, and two in a row', (tester) async {
      final subject = await pump(tester);
      await moveTo(tester, subject, 1);
      final semantics = tester.ensureSemantics();

      expect(find.bySemanticsLabel('حظيرة'), findsOneWidget);
      expect(find.bySemanticsLabel('متجر'), findsOneWidget);
      final cards = find.byType(AnswerCard);
      expect(cards, findsNWidgets(4));
      final first = tester.getSize(cards.first);
      expect(first.width, moreOrLessEquals(first.height, epsilon: 1));

      await tester.tap(cards.first);
      await tester.pump();
      expect(subject.state.selectedId, 'o1');
      semantics.dispose();
      await leaveClean(tester, subject);
    });

    testWidgets('the slower button plays slower, and says so', (tester) async {
      final subject = await pump(tester);
      await moveTo(tester, subject, 2);
      final semantics = tester.ensureSemantics();

      await tester.tap(find.text('lesson_slower'.tr()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(subject.state.slow, isTrue);
      expect(player.lastSpeed, ExerciseCubit.slowSpeed);
      expect(find.bySemanticsLabel('lesson_listen_slow'.tr()), findsOneWidget);
      semantics.dispose();
      await leaveClean(tester, subject);
    });

    testWidgets('the slower button keeps clear of the big one at 320dp', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        locale: const Locale('en'),
        size: narrowViewport,
      );
      await moveTo(tester, subject, 2);

      final slow = tester.getRect(find.text('lesson_slower'.tr()));
      final play = tester.getRect(find.byTooltip('lesson_stop_audio'.tr()));
      expect(slow.left, greaterThan(play.right));
      await leaveClean(tester, subject);
    });

    testWidgets('audio that fails offers a retry, and the options stay', (
      tester,
    ) async {
      player.fails = 1;
      final subject = await pump(tester);
      await moveTo(tester, subject, 2);

      expect(find.text('placement_audio_failed'.tr()), findsOneWidget);
      await tester.tap(find.text("I'm going to the market."));
      await tester.pump();
      expect(subject.state.canCheck, isTrue);

      await tester.tap(find.text('common_retry'.tr()));
      await tester.pump();
      await tester.pump();
      expect(subject.state.audio, ExerciseAudio.playing);
      await leaveClean(tester, subject);
    });

    testWidgets('a book question shows where it is', (tester) async {
      final subject = await pump(tester);
      expect(find.textContaining('34'), findsNothing);

      await moveTo(tester, subject, 3);

      expect(find.textContaining('34'), findsOneWidget);
      await leaveClean(tester, subject);
    });

    testWidgets('offline shows a band, and checking still works', (
      tester,
    ) async {
      final subject = await pump(tester);
      expect(find.text('lesson_offline'.tr()), findsNothing);

      connectivity.online = false;
      await tester.settleEntrance(const Duration(seconds: 1));
      expect(find.text('lesson_offline'.tr()), findsOneWidget);

      await tester.tap(find.text('goes'));
      await tester.pump();
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(lessons.answers, hasLength(1));

      connectivity.online = true;
      await tester.settleEntrance(const Duration(seconds: 1));
      expect(find.text('lesson_offline'.tr()), findsNothing);
      await leaveClean(tester, subject);
    });

    testWidgets('checking marks the answers, then next moves on', (
      tester,
    ) async {
      final subject = await pump(tester);
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.tap(find.byType(AppButton));
      await tester.settleEntrance(const Duration(seconds: 1));

      AnswerLook lookOf(String text) =>
          tester.widget<TextAnswer>(find.widgetWithText(TextAnswer, text)).look;
      expect(lookOf('go'), AnswerLook.wrong);
      expect(lookOf('goes'), AnswerLook.correct);
      expect(lookOf('going'), AnswerLook.dimmed);
      expect(find.text('lesson_next'.tr()), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.settleEntrance(const Duration(seconds: 1));
      expect(subject.state.index, 1);
      expect(find.text('barn'), findsOneWidget);
      await leaveClean(tester, subject);
    });

    testWidgets('the end of the lesson says so once', (tester) async {
      var finished = 0;
      final subject = await pump(tester, onFinished: () => finished++);
      await moveTo(tester, subject, 3);
      subject.select('o1');
      await subject.check();
      await subject.next();
      await tester.settleEntrance(const Duration(seconds: 1));

      expect(finished, 1);
      await leaveClean(tester, subject);
    });

    group('leaving', () {
      Future<void> openSheet(WidgetTester tester) async {
        await tester.tap(find.byTooltip('lesson_exit'.tr()));
        await tester.pump();
        await tester.settleEntrance(const Duration(seconds: 1));
      }

      testWidgets('asks first, with the guide, and stops the clip', (
        tester,
      ) async {
        final subject = await pump(tester);
        await moveTo(tester, subject, 2);
        expect(subject.state.audio, ExerciseAudio.playing);

        await openSheet(tester);

        expect(subject.state.audio, ExerciseAudio.idle);
        expect(find.text('lesson_exit_title'.tr()), findsOneWidget);
        expect(find.text('lesson_exit_body'.tr()), findsOneWidget);
        expect(find.byType(Mascot), findsOneWidget);
        await leaveClean(tester, subject);
      });

      testWidgets('going on stays', (tester) async {
        var left = 0;
        final subject = await pump(tester, onExit: () => left++);
        await openSheet(tester);

        await tester.tap(find.text('lesson_exit_stay'.tr()));
        await tester.pump();
        await tester.settleEntrance(const Duration(seconds: 1));

        expect(left, 0);
        expect(find.text('lesson_exit_title'.tr()), findsNothing);
        await leaveClean(tester, subject);
      });

      testWidgets('the scrim stays too', (tester) async {
        var left = 0;
        final subject = await pump(tester, onExit: () => left++);
        await openSheet(tester);

        await tester.tapAt(const Offset(20, 100));
        await tester.pump();
        await tester.settleEntrance(const Duration(seconds: 1));

        expect(left, 0);
        expect(find.text('lesson_exit_title'.tr()), findsNothing);
        await leaveClean(tester, subject);
      });

      testWidgets('leaving leaves', (tester) async {
        var left = 0;
        final subject = await pump(tester, onExit: () => left++);
        await openSheet(tester);

        await tester.tap(find.text('lesson_exit_leave'.tr()));
        await tester.pump();
        await tester.settleEntrance(const Duration(seconds: 1));

        expect(left, 1);
        await leaveClean(tester, subject);
      });

      testWidgets('the back button asks too', (tester) async {
        final subject = await pump(tester);

        await tester.binding.handlePopRoute();
        await tester.settleEntrance(const Duration(seconds: 1));

        expect(find.text('lesson_exit_title'.tr()), findsOneWidget);
        await leaveClean(tester, subject);
      });
    });

    testWidgets('under reduce motion nothing waves', (tester) async {
      final subject = cubit();
      addTearDown(subject.close);
      await tester.pumpLocalized(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: BlocProvider.value(
            value: subject,
            child: ExercisePage(onExit: () {}, onFinished: () {}),
          ),
        ),
      );
      await subject.start();
      await tester.settleEntrance(const Duration(seconds: 1));
      await moveTo(tester, subject, 2);

      expect(subject.state.audio, ExerciseAudio.playing);
      expect(tester.takeException(), isNull);
      await leaveClean(tester, subject);
    });
  });
}
