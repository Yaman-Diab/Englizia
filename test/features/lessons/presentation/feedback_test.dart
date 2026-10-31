import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/feedback_content.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/pages/exercise_page.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/feedback_sheet.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/word_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 1);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;
  late FakeClipPlayer player;
  late FakeSoundPlayer sounds;
  late List<Exercise> all;

  setUp(() {
    all = sampleExercises();
    lessons = FakeLessonRepository(exercises: all);
    player = FakeClipPlayer();
    sounds = FakeSoundPlayer();
  });

  ExerciseCubit cubit() => ExerciseCubit(
    lessons,
    player,
    FakeConnectivityService(),
    sounds,
    lessonId: 'les',
  );

  T first<T extends Exercise>() => all.whereType<T>().first;

  Future<ExerciseCubit> pump(
    WidgetTester tester, {
    required Exercise exercise,
    Locale locale = const Locale('ar'),
    Size size = defaultViewport,
    ThemeMode themeMode = ThemeMode.light,
    VoidCallback? onExplain,
  }) async {
    lessons.exercises = [exercise, first<SpellingExercise>()];
    final subject = cubit();
    addTearDown(subject.close);
    await tester.pumpLocalized(
      BlocProvider.value(
        value: subject,
        child: ExercisePage(
          onExit: () {},
          onFinished: (_) {},
          onExplain: onExplain ?? () {},
        ),
      ),
      locale: locale,
      size: size,
      themeMode: themeMode,
    );
    await subject.start();
    await tester.settleEntrance(_settled);
    return subject;
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(_settled);
  }

  /// Answers the choice question with [text], and checks.
  Future<void> answer(
    WidgetTester tester,
    ExerciseCubit subject,
    String text,
  ) async {
    final question = subject.state.question! as ChoiceExercise;
    subject.updateDraft(
      ChoiceDraft(question.options.firstWhere((o) => o.text == text).id),
    );
    await subject.check();
    await tester.settleEntrance(_settled);
  }

  group('the verdict', () {
    testWidgets('right: the title, with no right answer to show', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );

      await answer(tester, subject, 'goes');

      expect(find.text('lesson_fb_correct'.tr()), findsOneWidget);
      expect(find.text('lesson_fb_right_answer'.tr()), findsNothing);
      expect(find.text('lesson_next'.tr()), findsOneWidget);
      expect(find.text('lesson_check'.tr()), findsNothing);
      expect(sounds.played, [AppSound.correct]);
      await leave(tester);
    });

    testWidgets('wrong: the whole right answer, its sound and why', (
      tester,
    ) async {
      final exercise = first<MultipleChoiceExercise>();
      final subject = await pump(tester, exercise: exercise);

      await answer(tester, subject, 'go');

      expect(find.text('lesson_fb_wrong'.tr()), findsOneWidget);
      expect(find.text('lesson_fb_right_answer'.tr()), findsOneWidget);
      expect(find.textContaining('She goes to school'), findsWidgets);
      expect(find.text(exercise.explanation!), findsOneWidget);
      expect(find.byTooltip('lesson_fb_listen_sentence'.tr()), findsOneWidget);
      expect(sounds.played, [AppSound.incorrect]);
      await leave(tester);
    });

    testWidgets('the hint is mentioned only on a right answer', (tester) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );
      await subject.toggleHint();

      await answer(tester, subject, 'goes');

      expect(find.text('lesson_fb_assisted'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a right answer with no hint says nothing of it', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );

      await answer(tester, subject, 'goes');

      expect(find.text('lesson_fb_assisted'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('a right answer feels light, a wrong one stronger', (
      tester,
    ) async {
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
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );

      await answer(tester, subject, 'go');

      expect(calls, ['HapticFeedbackType.mediumImpact']);
      await leave(tester);
    });
  });

  group('the XP badge', () {
    testWidgets('shows what the server says a right answer earns', (
      tester,
    ) async {
      lessons.xpPerAnswer = 10;
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );

      await answer(tester, subject, 'goes');

      expect(find.text('xp_gain'.tr(namedArgs: {'xp': '10'})), findsWidgets);
      await leave(tester);
    });

    testWidgets('never on a wrong answer', (tester) async {
      lessons.xpPerAnswer = 10;
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );

      await answer(tester, subject, 'go');

      expect(find.textContaining('XP'), findsNothing);
      await leave(tester);
    });

    testWidgets('not at all until the server sends it', (tester) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );

      await answer(tester, subject, 'goes');

      expect(find.textContaining('XP'), findsNothing);
      await leave(tester);
    });
  });

  group('explain it to me', () {
    testWidgets('on a wrong answer, when the track allows it', (tester) async {
      lessons.explainEnabled = true;
      var opened = 0;
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
        onExplain: () => opened++,
      );

      await answer(tester, subject, 'go');
      await tester.tap(find.text('lesson_fb_explain'.tr()));
      await tester.pump();

      expect(opened, 1);
      await leave(tester);
    });

    testWidgets('not when the track doesn\'t', (tester) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );

      await answer(tester, subject, 'go');

      expect(find.text('lesson_fb_explain'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('not on a right answer', (tester) async {
      lessons.explainEnabled = true;
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );

      await answer(tester, subject, 'goes');

      expect(find.text('lesson_fb_explain'.tr()), findsNothing);
      await leave(tester);
    });
  });

  group('listening', () {
    testWidgets('wrong: listen again stands out, with what it said', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<ListenChooseExercise>(),
      );

      await answer(tester, subject, "I'm going to the garden.");

      expect(find.text('lesson_fb_listen_again'.tr()), findsOneWidget);
      expect(find.text('lesson_fb_heard'.tr()), findsOneWidget);
      expect(find.text('lesson_fb_right_answer'.tr()), findsNothing);

      final played = player.played;
      await tester.tap(find.text('lesson_fb_listen_again'.tr()));
      await tester.pump();
      await tester.pump();
      expect(player.played, played + 1);
      await subject.stopAudio();
      await leave(tester);
    });

    test('what told the clip apart is the strong part', () {
      final listen = first<ListenChooseExercise>();
      final garden = listen.options.firstWhere(
        (o) => o.text.contains('garden'),
      );

      final parts = heardParts(listen, garden.id);

      expect(parts.where((p) => p.strong).map((p) => p.text.trim()), [
        'market.',
      ]);
      expect(parts.map((p) => p.text).join(), listen.transcript);
    });
  });

  group('blanks and words', () {
    testWidgets('a blank wrong: not correct, with the sentence whole', (
      tester,
    ) async {
      final fill = first<FillChoicesExercise>();
      final subject = await pump(tester, exercise: fill);
      WordChip chip(String text) => fill.bank.firstWhere((c) => c.text == text);

      subject.updateDraft(SlotsDraft([chip('rains'), chip('would')]));
      await subject.check();
      await tester.settleEntrance(_settled);

      expect(find.text('lesson_fb_wrong'.tr()), findsOneWidget);
      expect(
        correctAnswerParts(fill).map((p) => p.text).join(),
        'If it rains tomorrow, we will stay at home.',
      );
      expect(
        correctAnswerParts(fill).where((p) => p.strong).map((p) => p.text),
        ['rains', 'will'],
      );
      await leave(tester);
    });

    testWidgets('words right: another form is offered', (tester) async {
      final order = first<WordOrderExercise>();
      final subject = await pump(tester, exercise: order);
      subject.updateDraft(
        SequenceDraft([
          for (final word in order.answerWords)
            order.bank.firstWhere((c) => c.text == word),
        ], needed: order.answerWords.length),
      );

      await subject.check();
      await tester.settleEntrance(_settled);

      expect(find.text('lesson_fb_other_form'.tr()), findsOneWidget);
      expect(find.textContaining('Before school,'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('matching ends with its own title, and no right answer', (
      tester,
    ) async {
      final matching = first<MatchingExercise>();
      final subject = await pump(tester, exercise: matching);
      subject.updateDraft(
        PairsDraft(
          total: matching.pairs.length,
          matched: {for (final pair in matching.pairs) pair.id},
        ),
      );

      await subject.check();
      await tester.settleEntrance(_settled);

      expect(find.text('lesson_fb_matched'.tr()), findsOneWidget);
      expect(find.text('lesson_fb_right_answer'.tr()), findsNothing);
      await leave(tester);
    });
  });

  group('an order only the server can judge', () {
    late WordOrderExercise order;
    late SequenceDraft draft;

    setUp(() {
      order = first<WordOrderExercise>();
      draft = SequenceDraft([
        for (final word in [
          'the',
          'chickens',
          'Sara',
          'feeds',
          'before',
          'school',
        ])
          order.bank.firstWhere((c) => c.text == word),
      ], needed: order.answerWords.length);
    });

    testWidgets('waits, with no «التالي» and no color on the words', (
      tester,
    ) async {
      final gate = Completer<void>();
      lessons.reviewGate = gate.future;
      final subject = await pump(tester, exercise: order);
      subject.updateDraft(draft);

      unawaited(subject.check());
      await tester.settleEntrance(_settled);

      expect(subject.state.evaluation, isA<ReviewPending>());
      expect(find.text('lesson_fb_reviewing'.tr()), findsOneWidget);
      expect(find.text('lesson_next'.tr()), findsNothing);
      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
      expect(sounds.played, isEmpty);
      for (final button in tester.widgetList<WordChipButton>(
        find.byType(WordChipButton),
      )) {
        expect(button.mark, isNull);
      }

      gate.complete();
      await tester.settleEntrance(_settled);

      expect(subject.state.evaluation?.correct, isTrue);
      expect(find.text('lesson_fb_correct'.tr()), findsOneWidget);
      expect(sounds.played, [AppSound.correct]);
      await leave(tester);
    });

    testWidgets('the server may find it wrong', (tester) async {
      lessons.review = const Ok(false);
      final subject = await pump(tester, exercise: order);
      subject.updateDraft(draft);

      await subject.check();
      await tester.settleEntrance(_settled);

      expect(find.text('lesson_fb_wrong'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('with no answer from it, later, and not wrong', (tester) async {
      lessons.review = const Err(NetworkFailure());
      final subject = await pump(tester, exercise: order);
      subject.updateDraft(draft);

      await subject.check();
      await tester.settleEntrance(_settled);

      expect(subject.state.evaluation, isA<ReviewLater>());
      expect(find.text('lesson_fb_later'.tr()), findsOneWidget);
      expect(find.text('lesson_next'.tr()), findsOneWidget);
      expect(sounds.played, isEmpty);
      await leave(tester);
    });

    testWidgets('the attempt is kept before asking', (tester) async {
      final subject = await pump(tester, exercise: order);
      subject.updateDraft(draft);

      await subject.check();

      expect(lessons.attempts, hasLength(1));
      expect(lessons.reviews, ['attempt-1']);
      await leave(tester);
    });

    testWidgets('another wrong order needs no server', (tester) async {
      final subject = await pump(tester, exercise: order);
      subject.updateDraft(
        SequenceDraft([
          for (final word in [
            'Sara',
            'feeds',
            'chickens',
            'the',
            'before',
            'school',
          ])
            order.bank.firstWhere((c) => c.text == word),
        ], needed: order.answerWords.length),
      );

      await subject.check();

      expect(lessons.reviews, isEmpty);
      expect(subject.state.evaluation?.correct, isFalse);
      await leave(tester);
    });
  });

  group('next', () {
    testWidgets('the sheet goes down first, then the question moves on', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );
      await answer(tester, subject, 'goes');

      await tester.tap(find.text('lesson_next'.tr()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(subject.state.index, 0);

      await tester.settleEntrance(_settled);
      expect(subject.state.index, 1);
      await tester.settleEntrance(_settled);
      expect(find.byType(FeedbackSheet), findsNothing);
      await leave(tester);
    });

    testWidgets('pressed twice, it moves one question', (tester) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );
      await answer(tester, subject, 'goes');

      await tester.tap(find.text('lesson_next'.tr()));
      await tester.pump();
      await tester.tap(find.text('lesson_next'.tr()), warnIfMissed: false);
      await tester.settleEntrance(_settled);

      expect(subject.state.index, 1);
      await leave(tester);
    });
  });

  group('reporting a problem', () {
    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.byTooltip('lesson_report'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
    }

    testWidgets('sends the reason and the answer, then thanks', (tester) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );
      await answer(tester, subject, 'go');
      await open(tester);

      expect(find.text('lesson_report_title'.tr()), findsOneWidget);
      final send = find.widgetWithText(AppButton, 'lesson_report_send'.tr());
      expect(tester.widget<AppButton>(send).onPressed, isNull);

      await tester.tap(find.text('lesson_report_audio'.tr()));
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(lessons.reports.single.reason, ProblemReason.audio);
      expect(lessons.reports.single.questionId, 'q1');
      expect(lessons.reports.single.draft, isA<ChoiceDraft>());
      expect(find.text('lesson_report_thanks'.tr()), findsOneWidget);
      // The sheet stays as it was.
      expect(find.text('lesson_fb_wrong'.tr()), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('lesson_report_thanks'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('the scrim sends nothing', (tester) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );
      await answer(tester, subject, 'goes');
      await open(tester);

      await tester.tapAt(const Offset(20, 40));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(lessons.reports, isEmpty);
      expect(find.text('lesson_report_thanks'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('leaving while it thanks leaves nothing behind', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );
      await answer(tester, subject, 'goes');
      await open(tester);
      await tester.tap(find.text('lesson_report_other'.tr()));
      await tester.pump();
      await tester.tap(find.text('lesson_report_send'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);

      await leave(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('the right sentence said', () {
    testWidgets('plays, then stops on a second tap', (tester) async {
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );
      await answer(tester, subject, 'go');

      await tester.tap(find.byTooltip('lesson_fb_listen_sentence'.tr()));
      await tester.pump();
      await tester.pump();
      expect(player.loaded.last, contains('she_goes'));
      expect(player.played, 1);

      await tester.tap(find.byTooltip('lesson_fb_listen_sentence'.tr()));
      await tester.pump();
      expect(player.stopped, 1);
      await leave(tester);
    });

    testWidgets('a clip that fails stays quiet here', (tester) async {
      player.fails = 1;
      final subject = await pump(
        tester,
        exercise: first<MultipleChoiceExercise>(),
      );
      await answer(tester, subject, 'go');

      await tester.tap(find.byTooltip('lesson_fb_listen_sentence'.tr()));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      await leave(tester);
    });
  });

  testLayouts('every verdict fits', (tester, layout) async {
    lessons.xpPerAnswer = 10;
    lessons.explainEnabled = true;
    for (final (exercise, text) in [
      (first<MultipleChoiceExercise>(), 'goes'),
      (first<MultipleChoiceExercise>(), 'go'),
      (all[3], 'where post office'),
      (first<ListenChooseExercise>(), "I'm going to the garden."),
    ]) {
      lessons.saved.clear();
      final subject = await pump(
        tester,
        exercise: exercise,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      await answer(tester, subject, text);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(_settled);
    }
  });

  testWidgets('a long explanation scrolls inside the sheet, with next fixed', (
    tester,
  ) async {
    final subject = await pump(tester, exercise: all[3], size: narrowViewport);

    await answer(tester, subject, 'where post office');

    final sheet = tester.getSize(find.byType(FeedbackSheet));
    expect(sheet.height, lessThanOrEqualTo(narrowViewport.height * .6 + 1));
    expect(find.text('lesson_next'.tr()), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('lesson_next'.tr())).dy,
      lessThan(narrowViewport.height),
    );
    await leave(tester);
  });

  testWidgets('under reduce motion it just appears', (tester) async {
    lessons.exercises = [
      first<MultipleChoiceExercise>(),
      first<SpellingExercise>(),
    ];
    final subject = cubit();
    addTearDown(subject.close);
    await tester.pumpLocalized(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: BlocProvider.value(
          value: subject,
          child: ExercisePage(
            onExit: () {},
            onFinished: (_) {},
            onExplain: () {},
          ),
        ),
      ),
    );
    await subject.start();
    await tester.settleEntrance(_settled);

    await answer(tester, subject, 'goes');

    expect(find.text('lesson_fb_correct'.tr()), findsOneWidget);
    expect(tester.takeException(), isNull);
    await leave(tester);
  });
}
