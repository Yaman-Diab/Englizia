import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/design_system/motion/count_up.dart';
import 'package:englizia/core/design_system/widgets/xp_amount.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/presentation/complete/cubit/lesson_complete_cubit.dart';
import 'package:englizia/features/lessons/presentation/complete/pages/lesson_complete_page.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/unit_chain.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 3);

const _unit = UnitProgress(
  number: 3,
  title: 'Farm',
  steps: [
    UnitStep(lessonId: 'a', kind: LessonKind.vocabulary, done: true),
    UnitStep(lessonId: 'les', kind: LessonKind.conversation, done: false),
    UnitStep(lessonId: 'b', kind: LessonKind.grammarVideo, done: false),
  ],
);

const _next = NextStep(
  kind: NextKind.lesson,
  lessonId: 'b',
  lessonKind: LessonKind.grammarVideo,
  title: 'Present simple',
);

const _summary = LessonSummary(
  lessonId: 'les',
  lessonVersion: 3,
  rightFirstTime: 5,
  counted: 6,
  pending: 0,
  seconds: 420,
  outline: LessonOutline(
    title: 'A day on the farm',
    earnsXp: true,
    unit: _unit,
    next: _next,
  ),
);

const _full = LessonResult(
  xp: 15,
  wordsSaved: 3,
  concepts: ['the s of he and she'],
  goal: DailyGoal(before: 5, now: 7, target: 10),
  streak: StreakDays(before: 6, now: 6),
);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;
  late FakeConnectivityService connectivity;
  late FakeSoundPlayer sounds;

  setUp(() {
    lessons = FakeLessonRepository();
    connectivity = FakeConnectivityService();
    sounds = FakeSoundPlayer();
  });

  Future<LessonCompleteCubit> pump(
    WidgetTester tester, {
    LessonSummary summary = _summary,
    Locale locale = const Locale('ar'),
    Size size = defaultViewport,
    ThemeMode themeMode = ThemeMode.light,
    ValueChanged<NextStep>? onNext,
    VoidCallback? onBack,
    VoidCallback? onWords,
    Duration settle = _settled,
  }) async {
    final subject = LessonCompleteCubit(
      lessons,
      connectivity,
      sounds,
      summary: summary,
    );
    addTearDown(subject.close);
    await tester.pumpLocalized(
      BlocProvider.value(
        value: subject,
        child: LessonCompletePage(
          onNext: onNext ?? (_) {},
          onBack: onBack ?? () {},
          onWords: onWords ?? () {},
        ),
      ),
      locale: locale,
      size: size,
      themeMode: themeMode,
    );
    unawaited(subject.start());
    await tester.pump();
    await tester.settleEntrance(settle);
    return subject;
  }

  group('the counter', () {
    Widget counter(int value, {bool reduce = false, VoidCallback? onDone}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: CountUp(
              value: value,
              onDone: onDone,
              builder: (_, shown) => Text('$shown'),
            ),
          ),
        );

    testWidgets('counts from zero to its value, and says when it lands', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(counter(15, onDone: () => done++));
      expect(find.text('0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      final midway = int.parse(tester.widget<Text>(find.byType(Text)).data!);
      expect(midway, inExclusiveRange(0, 15));

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('15'), findsOneWidget);
      expect(done, 1);
    });

    testWidgets('a new value counts on from what it shows', (tester) async {
      await tester.pumpWidget(counter(15));
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(counter(20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midway = int.parse(tester.widget<Text>(find.byType(Text)).data!);
      expect(midway, inExclusiveRange(15, 20));

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('under reduce motion the number is simply there', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(counter(15, reduce: true, onDone: () => done++));

      expect(find.text('15'), findsOneWidget);
      expect(done, 0);
    });

    testWidgets('jumps to the end when motion is taken away', (tester) async {
      await tester.pumpWidget(counter(15));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(counter(15, reduce: true));
      await tester.pump();

      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('a screen reader hears only the amount', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpLocalized(
        const Center(child: XpAmount(xp: 15, style: TextStyle(fontSize: 22))),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.bySemanticsLabel('xp_gain'.tr(namedArgs: {'xp': '15'})),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
      semantics.dispose();
    });
  });

  group('the numbers', () {
    testWidgets('the whole of it: points, numbers, words, review, day', (
      tester,
    ) async {
      lessons.completion = const Ok(_full);
      await pump(tester);

      expect(find.text('lesson_complete_title'.tr()), findsOneWidget);
      expect(find.text('A day on the farm'), findsOneWidget);
      expect(find.text('xp_gain'.tr(namedArgs: {'xp': '15'})), findsWidgets);
      expect(
        find.text(
          'lesson_done_first_value'.tr(namedArgs: {'right': '5', 'total': '6'}),
        ),
        findsOneWidget,
      );
      expect(
        find.text('lesson_done_minutes'.tr(namedArgs: {'minutes': '7'})),
        findsOneWidget,
      );
      expect(find.text('lesson_done_words'.plural(3)), findsOneWidget);
      expect(find.text('the s of he and she'), findsOneWidget);
      expect(find.text('7/10'), findsOneWidget);
      expect(find.text('lesson_done_goal_reached'.tr()), findsNothing);
      expect(sounds.played, [AppSound.lessonComplete]);
    });

    testWidgets('what the server leaves out is not shown', (tester) async {
      lessons.completion = const Ok(LessonResult());
      await pump(tester);

      expect(find.byType(XpAmount), findsNothing);
      expect(find.text('lesson_done_counted_later'.tr()), findsNothing);
      expect(find.text('lesson_done_today'.tr()), findsNothing);
      expect(find.text('lesson_done_review'.tr()), findsNothing);
      expect(find.text('lesson_done_time'.tr()), findsOneWidget);
    });

    testWidgets('the server has the last word on the numbers', (tester) async {
      lessons.completion = const Ok(
        LessonResult(xp: 15, rightFirstTime: 6, counted: 6),
      );
      await pump(tester);

      expect(find.text('lesson_done_perfect'.tr()), findsOneWidget);
      expect(find.text('lesson_done_review'.tr()), findsNothing);
    });

    testWidgets('with nothing counted there is no such number', (tester) async {
      lessons.completion = const Ok(LessonResult(xp: 15));
      await pump(
        tester,
        summary: const LessonSummary(
          lessonId: 'les',
          lessonVersion: 3,
          rightFirstTime: 0,
          counted: 0,
          pending: 0,
          seconds: 10,
          outline: LessonOutline(earnsXp: true),
        ),
      );

      expect(find.text('lesson_done_first'.tr()), findsNothing);
      expect(
        find.text('lesson_done_minutes'.tr(namedArgs: {'minutes': '1'})),
        findsOneWidget,
        reason: 'a short lesson still took a minute',
      );
    });

    testWidgets('a question waiting to be judged is said, not counted wrong', (
      tester,
    ) async {
      lessons.completion = const Ok(LessonResult(xp: 15, pending: 1));
      await pump(tester);

      expect(find.text('lesson_done_pending'.plural(1)), findsOneWidget);
      expect(find.text('lesson_done_perfect'.tr()), findsNothing);
    });
  });

  group('reaching the goal', () {
    const reached = LessonResult(
      xp: 15,
      goal: DailyGoal(before: 8, now: 10, target: 10),
      streak: StreakDays(before: 6, now: 7),
    );

    testWidgets('says so, once, with its sound and a stronger touch', (
      tester,
    ) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        },
      );
      lessons.completion = const Ok(reached);
      await pump(tester);

      expect(find.text('lesson_done_goal_reached'.tr()), findsOneWidget);
      expect(find.text('lesson_done_goal_done'.tr()), findsOneWidget);
      expect(find.text('10/10'), findsNothing);
      expect(sounds.played, [AppSound.lessonComplete, AppSound.goalReached]);
      expect(haptics, contains('HapticFeedbackType.mediumImpact'));
    });

    testWidgets('brings the card into view, as it is under the fold', (
      tester,
    ) async {
      lessons.completion = const Ok(reached);
      await pump(
        tester,
        size: narrowViewport,
        settle: const Duration(milliseconds: 1),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.pixels, position.maxScrollExtent);
      expect(position.pixels, greaterThan(0));
    });

    testWidgets('an ordinary day stays where it opened', (tester) async {
      lessons.completion = const Ok(_full);
      await pump(tester, size: narrowViewport);

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.pixels, 0);
    });

    testWidgets('a goal already met before this lesson has no moment', (
      tester,
    ) async {
      lessons.completion = const Ok(
        LessonResult(
          xp: 15,
          goal: DailyGoal(before: 12, now: 14, target: 10),
          streak: StreakDays(before: 7, now: 7),
        ),
      );
      await pump(tester);

      expect(find.text('lesson_done_goal_reached'.tr()), findsNothing);
      expect(sounds.played, [AppSound.lessonComplete]);
    });
  });

  group('the unit', () {
    testWidgets('its last lesson says the unit is done', (tester) async {
      lessons.completion = const Ok(
        LessonResult(
          xp: 15,
          unit: _unit,
          next: NextStep(kind: NextKind.unitReview),
        ),
      );
      await pump(tester);

      expect(
        find.text('lesson_done_unit'.tr(namedArgs: {'unit': '3'})),
        findsOneWidget,
      );
      expect(find.text('lesson_done_start_review'.tr()), findsOneWidget);
      expect(find.text('lesson_done_next_review_line'.tr()), findsOneWidget);
    });

    testWidgets('no review: on to the next unit', (tester) async {
      lessons.completion = const Ok(
        LessonResult(
          xp: 15,
          unit: _unit,
          next: NextStep(kind: NextKind.unit, unitNumber: 4, title: 'Market'),
        ),
      );
      await pump(tester);

      expect(find.text('lesson_done_next_unit'.tr()), findsOneWidget);
      expect(
        find.text(
          'lesson_done_next_unit_line'.tr(
            namedArgs: {'unit': '4', 'title': 'Market'},
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a lesson done again says so', (tester) async {
      lessons.completion = const Ok(LessonResult(xp: 5, replay: true));
      await pump(tester);

      expect(find.text('lesson_done_replayed'.tr()), findsOneWidget);
    });

    testWidgets('the line reaches as far as the chain has come', (
      tester,
    ) async {
      lessons.completion = const Ok(LessonResult(xp: 15));
      await pump(tester);

      final fill = find.byWidgetPredicate(
        (widget) => widget is FractionallySizedBox && widget.heightFactor == 1,
      );
      final track = tester.getSize(find.byType(UnitChain)).width;
      final size = tester.getSize(fill);
      expect(size.height, greaterThan(0), reason: 'a line with no height');
      expect(size.width, greaterThan(track / 3));
    });

    test('this lesson counts as done before the server says so', () {
      const state = LessonCompleteState(summary: _summary);

      expect(state.unit?.doneInARow, 2);
    });
  });

  group('the server', () {
    testWidgets('unreachable: counted later, and saved on the phone', (
      tester,
    ) async {
      lessons.completion = const Err(NetworkFailure());
      await pump(tester);

      expect(find.text('lesson_done_counted_later'.tr()), findsOneWidget);
      expect(find.text('lesson_done_saved_on_phone'.tr()), findsOneWidget);
      expect(find.text('lesson_complete_title'.tr()), findsOneWidget);
      expect(
        find.text(
          'lesson_done_first_value'.tr(namedArgs: {'right': '5', 'total': '6'}),
        ),
        findsOneWidget,
        reason: 'what the phone counted is still true',
      );
    });

    testWidgets('slow: after two seconds the same, and it counts on arrival', (
      tester,
    ) async {
      final gate = Completer<void>();
      lessons
        ..completionGate = gate.future
        ..completion = const Ok(_full);
      await pump(tester, settle: const Duration(seconds: 1));
      expect(find.text('lesson_done_counted_later'.tr()), findsNothing);

      await tester.settleEntrance(const Duration(milliseconds: 1100));
      expect(find.text('lesson_done_counted_later'.tr()), findsOneWidget);

      gate.complete();
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(find.text('lesson_done_counted_later'.tr()), findsNothing);
      expect(find.text('lesson_done_saved_on_phone'.tr()), findsNothing);
      expect(find.text('lesson_done_today'.tr()), findsOneWidget);
    });

    testWidgets('asks again when the connection returns', (tester) async {
      lessons.completion = const Err(NetworkFailure());
      final subject = await pump(tester);
      expect(lessons.completions, hasLength(1));

      lessons.completion = const Ok(_full);
      connectivity
        ..online = false
        ..online = true;
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(lessons.completions, hasLength(2));
      expect(subject.state.result, _full);
    });
  });

  group('the way out', () {
    testWidgets('the next lesson, and back to the unit', (tester) async {
      NextStep? went;
      var back = 0;
      lessons.completion = const Ok(_full);
      await pump(tester, onNext: (next) => went = next, onBack: () => back++);

      await tester.tap(find.text('lesson_done_next_lesson'.tr()));
      await tester.pump();
      expect(went, _next);

      await tester.tap(find.text('lesson_done_back'.tr()));
      await tester.pump();
      expect(back, 1);
    });

    testWidgets('the phone back is back to the unit', (tester) async {
      var back = 0;
      lessons.completion = const Ok(_full);
      await pump(tester, onBack: () => back++);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(back, 1);
    });

    testWidgets('the words open their list', (tester) async {
      var words = 0;
      lessons.completion = const Ok(_full);
      await pump(tester, onWords: () => words++);

      await tester.tap(find.text('lesson_done_show_words'.tr()));
      await tester.pump();

      expect(words, 1);
    });

    testWidgets('the end of the track leaves only the way back', (
      tester,
    ) async {
      lessons.completion = const Ok(LessonResult(xp: 15));
      await pump(
        tester,
        summary: const LessonSummary(
          lessonId: 'les',
          lessonVersion: 3,
          rightFirstTime: 1,
          counted: 1,
          pending: 0,
          seconds: 60,
          outline: LessonOutline(earnsXp: true),
        ),
      );

      expect(find.text('lesson_done_next_lesson'.tr()), findsNothing);
      expect(find.text('lesson_done_back'.tr()), findsOneWidget);
    });
  });

  group('what the session counts', () {
    late List<Exercise> all;

    setUp(() => all = sampleExercises());

    T first<T extends Exercise>() => all.whereType<T>().first;

    ExerciseCubit session(List<Exercise> questions) {
      lessons.exercises = questions;
      final subject = ExerciseCubit(
        lessons,
        FakeClipPlayer(),
        connectivity,
        sounds,
        lessonId: 'les',
      );
      addTearDown(subject.close);
      return subject;
    }

    Future<void> answer(ExerciseCubit subject, ExerciseDraft draft) async {
      subject.updateDraft(draft);
      await subject.check();
      await subject.next();
    }

    test('right at the first attempt, of those that count', () async {
      final choices = sampleChoiceExercises().cast<ChoiceExercise>();
      final subject = session([choices[0], choices[1], choices[2]]);
      await subject.start();

      await answer(subject, ChoiceDraft(choices[0].answerId));
      final wrong = choices[1].options.firstWhere(
        (o) => o.id != choices[1].answerId,
      );
      await answer(subject, ChoiceDraft(wrong.id));
      await subject.skipQuestion();

      final summary = subject.summary;
      expect(summary.rightFirstTime, 1);
      expect(
        summary.counted,
        2,
        reason: 'a skipped question counts neither way',
      );
      expect(summary.pending, 0);
      expect(summary.lessonVersion, FakeLessonRepository.version);
    });

    test(
      'a matching with a mistake on the way was not at the first try',
      () async {
        final pairs = first<MatchingExercise>();
        final subject = session([pairs]);
        await subject.start();

        subject.updateDraft(
          PairsDraft(
            total: pairs.pairs.length,
            matched: {for (final pair in pairs.pairs) pair.id},
            mistakes: {pairs.pairs.first.id},
          ),
        );
        await subject.check();

        expect(subject.summary.rightFirstTime, 0);
        expect(subject.summary.counted, 1);
      },
    );

    test('an order only the server can judge waits, and then counts', () async {
      final order = first<WordOrderExercise>();
      final gate = Completer<void>();
      lessons.reviewGate = gate.future;
      final subject = session([order]);
      await subject.start();

      subject.updateDraft(
        SequenceDraft([
          for (final (i, word) in order.reviewable.first.split(' ').indexed)
            WordChip(id: 'c$i', text: word),
        ], needed: order.answerWords.length),
      );
      final checking = subject.check();
      await Future<void>.delayed(Duration.zero);
      expect(subject.summary.pending, 1);
      expect(subject.summary.counted, 0);

      gate.complete();
      await checking;

      expect(subject.summary.pending, 0);
      expect(subject.summary.rightFirstTime, 1);
      expect(subject.summary.counted, 1);
    });

    test('a judgement that fails stays waiting, never wrong', () async {
      final order = first<WordOrderExercise>();
      lessons.review = const Err(NetworkFailure());
      final subject = session([order]);
      await subject.start();

      subject.updateDraft(
        SequenceDraft([
          for (final (i, word) in order.reviewable.first.split(' ').indexed)
            WordChip(id: 'c$i', text: word),
        ], needed: order.answerWords.length),
      );
      await subject.check();

      expect(subject.summary.pending, 1);
      expect(subject.summary.counted, 0);
    });

    test('the AI allowance out counts neither way; answered counts', () async {
      final speak = first<SpeakAnswerExercise>();
      lessons.spokenReview = const Ok(ReviewQuotaOut());
      final out = session([speak]);
      await out.start();
      out.updateDraft(const SpokenDraft('I rest'));
      await out.check();
      expect(out.summary.counted, 0);

      lessons.spokenReview = const Ok(SpokenAnswered(note: 'n'));
      final answered = session([speak]);
      await answered.start();
      answered.updateDraft(const SpokenDraft('I rest'));
      await answered.check();
      expect(answered.summary.rightFirstTime, 1);
    });

    test('carries on counting where the learner left it', () async {
      final choices = sampleChoiceExercises().cast<ChoiceExercise>();
      lessons.saved['les'] = ExerciseProgress(
        done: {choices[0].id, choices[1].id},
        right: {choices[0].id},
        uncounted: {choices[1].id},
        seconds: 300,
      );
      final subject = session([choices[0], choices[1], choices[2]]);
      await subject.start();

      await answer(subject, ChoiceDraft(choices[2].answerId));

      expect(subject.summary.rightFirstTime, 2);
      expect(subject.summary.counted, 2);
      expect(subject.summary.seconds, greaterThanOrEqualTo(300));
    });

    test('the lesson brings its place in the unit', () async {
      lessons.outline = const LessonOutline(title: 'T', unit: _unit);
      final subject = session([sampleChoiceExercises().first]);
      await subject.start();

      expect(subject.summary.outline.title, 'T');
      expect(subject.summary.outline.unit, _unit);
    });
  });

  testWidgets('a press anywhere jumps to the end', (tester) async {
    lessons.completion = const Ok(_full);
    await pump(tester, settle: const Duration(milliseconds: 100));
    await tester.pump();

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(find.text('xp_gain'.tr(namedArgs: {'xp': '15'})), findsWidgets);
    expect(
      find.text('xp_gain'.tr(namedArgs: {'xp': '0'})),
      findsNothing,
      reason: 'the count is over at once',
    );
    await tester.pump(_settled);
  });

  testWidgets('under reduce motion everything is simply there', (tester) async {
    lessons.completion = const Ok(_full);
    final subject = LessonCompleteCubit(
      lessons,
      connectivity,
      sounds,
      summary: _summary,
    );
    addTearDown(subject.close);
    await tester.pumpLocalized(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: BlocProvider.value(
          value: subject,
          child: LessonCompletePage(
            onNext: (_) {},
            onBack: () {},
            onWords: () {},
          ),
        ),
      ),
    );
    unawaited(subject.start());
    await tester.pump();
    await tester.pump();

    expect(find.text('xp_gain'.tr(namedArgs: {'xp': '15'})), findsWidgets);
    expect(find.text('7/10'), findsOneWidget);
    await tester.pump(_settled);
  });

  testLayouts('every state fits', (tester, layout) async {
    for (final result in const [
      _full,
      LessonResult(),
      LessonResult(
        xp: 1500,
        wordsSaved: 12,
        concepts: ['the s of he and she', 'questions with do'],
        pending: 2,
        goal: DailyGoal(before: 8, now: 10, target: 10),
        streak: StreakDays(before: 99, now: 100),
      ),
    ]) {
      lessons.completion = Ok(result);
      await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(_settled);
    }
  });
}
