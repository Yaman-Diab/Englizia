import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/pages/exercise_page.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/word_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 1);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;

  ExerciseCubit cubitFor(List<Exercise> exercises) {
    lessons = FakeLessonRepository(exercises: exercises);
    return ExerciseCubit(
      lessons,
      FakeClipPlayer(),
      FakeConnectivityService(),
      FakeSoundPlayer(),
      lessonId: 'les',
    );
  }

  Exercise template<T extends Exercise>() =>
      sampleExercises().whereType<T>().first;

  Future<ExerciseCubit> pump<T extends Exercise>(
    WidgetTester tester, {
    Locale locale = const Locale('ar'),
    Size size = defaultViewport,
    ThemeMode themeMode = ThemeMode.light,
    Exercise? exercise,
    bool reduce = false,
  }) async {
    final subject = cubitFor([exercise ?? template<T>()]);
    addTearDown(subject.close);
    await tester.pumpLocalized(
      MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduce),
        child: BlocProvider.value(
          value: subject,
          child: ExercisePage(
            onExit: () {},
            onFinished: (_) {},
            onExplain: (_) {},
          ),
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

  Future<void> tapWord(WidgetTester tester, String word) async {
    await tester.tap(find.widgetWithText(WordChipButton, word).last);
    await tester.pump();
    await tester.settleEntrance(_settled);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(_settled);
  }

  AppButton cta(WidgetTester tester) =>
      tester.widget<AppButton>(find.byType(AppButton));

  group('filling the blanks', () {
    SlotsDraft draftOf(ExerciseCubit subject) =>
        subject.state.draft! as SlotsDraft;

    testWidgets('a word goes to the active blank, then the next one', (
      tester,
    ) async {
      final subject = await pump<FillChoicesExercise>(tester);
      expect(cta(tester).onPressed, isNull);

      await tapWord(tester, 'rains');
      expect(draftOf(subject).chips.map((c) => c?.text), ['rains', null]);
      expect(cta(tester).onPressed, isNull);

      await tapWord(tester, 'will');
      expect(draftOf(subject).chips.map((c) => c?.text), ['rains', 'will']);
      expect(cta(tester).onPressed, isNotNull);
      await leave(tester);
    });

    testWidgets('tapping a blank makes it the active one', (tester) async {
      final subject = await pump<FillChoicesExercise>(tester);
      await tester.tap(
        find.bySemanticsLabel('lesson_blank'.tr(namedArgs: {'number': '2'})),
      );
      await tester.settleEntrance(_settled);

      await tapWord(tester, 'will');

      expect(draftOf(subject).chips.map((c) => c?.text), [null, 'will']);
      await leave(tester);
    });

    testWidgets('a word in the sentence goes back, and its blank is active', (
      tester,
    ) async {
      final subject = await pump<FillChoicesExercise>(tester);
      await tapWord(tester, 'rains');
      await tapWord(tester, 'will');

      await tester.tap(
        find.bySemanticsLabel(
          'lesson_chip_remove'.tr(namedArgs: {'word': 'rains'}),
        ),
      );
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(draftOf(subject).chips.map((c) => c?.text), [null, 'will']);
      expect(cta(tester).onPressed, isNull);
      await tapWord(tester, 'is');
      expect(draftOf(subject).chips.map((c) => c?.text), ['is', 'will']);
      await leave(tester);
    });

    testWidgets('a word in use leaves its shadow, and can\'t be used twice', (
      tester,
    ) async {
      final subject = await pump<FillChoicesExercise>(tester);
      final bank = tester.getSize(find.byType(WordBank));
      await tapWord(tester, 'rains');

      // The rest of the bank doesn't move.
      expect(tester.getSize(find.byType(WordBank)), bank);
      expect(find.widgetWithText(WordChipButton, 'rains'), findsNothing);
      expect(draftOf(subject).chips.first?.text, 'rains');
      await leave(tester);
    });

    testWidgets('nothing throws while a word is in the air', (tester) async {
      await pump<FillChoicesExercise>(tester);
      await tester.tap(find.widgetWithText(WordChipButton, 'rains'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
      await tester.pump(_settled);
      await leave(tester);
    });

    testWidgets('checking locks it, and marks each blank', (tester) async {
      final subject = await pump<FillChoicesExercise>(tester);
      await tapWord(tester, 'rains');
      await tapWord(tester, 'would');

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(subject.state.evaluation, const SlotsEvaluation([true, false]));
      expect(
        find.bySemanticsLabel(
          'lesson_chip_wrong'.tr(namedArgs: {'word': 'would'}),
        ),
        findsOneWidget,
      );
      await tapWord(tester, 'is');
      expect(draftOf(subject).chips.last?.text, 'would');
      await leave(tester);
    });
  });

  group('ordering the words', () {
    List<String> placed(ExerciseCubit subject) => [
      for (final chip in (subject.state.draft! as SequenceDraft).chips)
        chip.text,
    ];

    Future<void> build(WidgetTester tester, List<String> words) async {
      for (final word in words) {
        await tapWord(tester, word);
      }
    }

    testWidgets('the guide says the meaning', (tester) async {
      await pump<WordOrderExercise>(tester);

      expect(find.byType(Mascot), findsOneWidget);
      expect(find.textContaining('سارة'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('checking waits for as many words as the answer has', (
      tester,
    ) async {
      await pump<WordOrderExercise>(tester);

      await build(tester, ['Sara', 'feeds', 'the', 'chickens', 'before']);
      expect(cta(tester).onPressed, isNull);

      await build(tester, ['school']);
      expect(cta(tester).onPressed, isNotNull);
      await leave(tester);
    });

    testWidgets('a word taken out closes the gap', (tester) async {
      final subject = await pump<WordOrderExercise>(tester);
      await build(tester, ['Sara', 'feeds', 'the']);
      final the = tester.getTopLeft(
        find.widgetWithText(WordChipButton, 'the').first,
      );

      await tester.tap(find.widgetWithText(WordChipButton, 'feeds').first);
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(placed(subject), ['Sara', 'the']);
      expect(
        tester.getTopLeft(find.widgetWithText(WordChipButton, 'the').first).dx,
        lessThan(the.dx),
      );
      await leave(tester);
    });

    testWidgets('the right order, and another accepted one, are correct', (
      tester,
    ) async {
      final subject = await pump<WordOrderExercise>(tester);
      await build(tester, [
        'before',
        'school',
        'Sara',
        'feeds',
        'the',
        'chickens',
      ]);

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(subject.state.evaluation?.correct, isTrue);
      await leave(tester);
    });

    testWidgets('a wrong order marks each word', (tester) async {
      final subject = await pump<WordOrderExercise>(tester);
      await build(tester, [
        'Sara',
        'feeds',
        'chickens',
        'the',
        'before',
        'school',
      ]);

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(
        subject.state.evaluation,
        const SequenceEvaluation(
          words: [true, true, false, false, true, true],
          correct: false,
        ),
      );
      await leave(tester);
    });
  });

  group('matching', () {
    final word = sampleExercises().whereType<MatchingExercise>().first;
    final pictures = sampleExercises().whereType<MatchingExercise>().last;

    Future<void> pair(WidgetTester tester, String first, String second) async {
      await tester.tap(find.text(first));
      await tester.pump();
      await tester.tap(find.text(second));
      await tester.pump();
    }

    Future<void> leaveMatching(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 2));
      await leave(tester);
    }

    testWidgets('it has no check button', (tester) async {
      await pump<MatchingExercise>(tester, exercise: word);

      expect(find.byType(AppButton), findsNothing);
      await leaveMatching(tester);
    });

    testWidgets('a right pair counts, with no mistake', (tester) async {
      final subject = await pump<MatchingExercise>(tester, exercise: word);

      await pair(tester, 'حقل', 'field');

      final draft = subject.state.draft! as PairsDraft;
      expect(draft.matched, {'field'});
      expect(draft.mistakes, isEmpty);
      await leaveMatching(tester);
    });

    testWidgets('a wrong pair goes back, and its first mistake is noted', (
      tester,
    ) async {
      final subject = await pump<MatchingExercise>(tester, exercise: word);

      await pair(tester, 'حقل', 'egg');

      var draft = subject.state.draft! as PairsDraft;
      expect(draft.matched, isEmpty);
      expect(draft.mistakes, {'field'});
      await tester.pump(const Duration(milliseconds: 700));

      await pair(tester, 'حقل', 'cow');
      draft = subject.state.draft! as PairsDraft;
      expect(draft.mistakes, {'field'});

      await tester.pump(const Duration(milliseconds: 700));
      await pair(tester, 'حقل', 'field');
      draft = subject.state.draft! as PairsDraft;
      expect(draft.matched, {'field'});
      await leaveMatching(tester);
    });

    testWidgets('a card tapped twice is let go; another takes its place', (
      tester,
    ) async {
      final subject = await pump<MatchingExercise>(tester, exercise: word);
      await tester.tap(find.text('حقل'));
      await tester.pump();
      await tester.tap(find.text('حقل'));
      await tester.pump();
      await tester.tap(find.text('field'));
      await tester.pump();
      expect(subject.state.draft, isNull);

      await tester.tap(find.text('egg'));
      await tester.pump();
      await tester.tap(find.text('field'));
      await tester.pump();
      await tester.tap(find.text('حقل'));
      await tester.pump();

      expect((subject.state.draft! as PairsDraft).matched, {'field'});
      await leaveMatching(tester);
    });

    testWidgets('the last pair ends the question by itself', (tester) async {
      final subject = await pump<MatchingExercise>(tester, exercise: word);

      await pair(tester, 'حقل', 'field');
      await pair(tester, 'بيضة', 'egg');
      await pair(tester, 'حظيرة', 'barn');
      await pair(tester, 'بقرة', 'cow');
      expect(subject.state.checked, isFalse);
      await pair(tester, 'دجاجة', 'chicken');
      expect(subject.state.checked, isFalse);

      await tester.pump(const Duration(milliseconds: 450));

      expect(subject.state.evaluation?.correct, isTrue);
      expect(lessons.attempts, hasLength(1));
      await leaveMatching(tester);
    });

    testWidgets('pictures have their names', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump<MatchingExercise>(tester, exercise: pictures);

      expect(
        find.bySemanticsLabel(
          'lesson_picture_named'.tr(namedArgs: {'name': 'بقرة'}),
        ),
        findsOneWidget,
      );
      semantics.dispose();
      await leaveMatching(tester);
    });

    testWidgets('leaving before the end cancels what was waiting', (
      tester,
    ) async {
      await pump<MatchingExercise>(tester, exercise: word);
      await pair(tester, 'حقل', 'field');
      await pair(tester, 'بيضة', 'egg');

      await leave(tester);
      expect(tester.takeException(), isNull);
    });
  });

  testLayouts('every template fits', (tester, layout) async {
    for (final exercise in sampleExercises().where(
      (e) =>
          e is FillChoicesExercise ||
          e is WordOrderExercise ||
          e is MatchingExercise,
    )) {
      final subject = cubitFor([exercise]);
      addTearDown(subject.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: ExercisePage(
            onExit: () {},
            onFinished: (_) {},
            onExplain: (_) {},
          ),
        ),
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      await subject.start();
      await tester.settleEntrance(_settled);
      expect(tester.takeException(), isNull);
      if (exercise is WordOrderExercise) {
        for (final word in exercise.answerWords) {
          await tester.tap(find.widgetWithText(WordChipButton, word).last);
          await tester.pump();
          await tester.settleEntrance(_settled);
        }
        expect(tester.takeException(), isNull);
      }
      if (exercise is FillChoicesExercise) {
        for (final blank in exercise.blanks) {
          await tester.tap(
            find.widgetWithText(WordChipButton, blank.answer).last,
          );
          await tester.pump();
          await tester.settleEntrance(_settled);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(_settled);
    }
  });

  testWidgets('under reduce motion a word just appears where it landed', (
    tester,
  ) async {
    final subject = await pump<FillChoicesExercise>(tester, reduce: true);

    await tester.tap(find.widgetWithText(WordChipButton, 'rains'));
    await tester.pump();

    expect((subject.state.draft! as SlotsDraft).chips.first?.text, 'rains');
    expect(tester.takeException(), isNull);
    await tester.settleEntrance(_settled);
    await leave(tester);
  });
}
