import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/feedback_content.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/pages/exercise_page.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/passage_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 1);

/// Tall enough for a text and all of its options at once.
const _tall = Size(375, 1100);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;
  late FakeSpeechListener speech;
  late FakeMicPermission permission;
  late FakeSoundPlayer sounds;
  late MicCubit mic;
  late List<Exercise> all;

  setUp(() {
    all = sampleExercises();
    lessons = FakeLessonRepository(exercises: all);
    speech = FakeSpeechListener();
    permission = FakeMicPermission()..access = MicAccess.granted;
    sounds = FakeSoundPlayer();
  });

  T first<T extends Exercise>() => all.whereType<T>().first;

  Future<ExerciseCubit> pumpAll(
    WidgetTester tester, {
    required List<Exercise> exercises,
    Locale locale = const Locale('ar'),
    Size size = defaultViewport,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    lessons.exercises = exercises;
    final subject = ExerciseCubit(
      lessons,
      FakeClipPlayer(),
      FakeConnectivityService(),
      sounds,
      lessonId: 'les',
    );
    mic = MicCubit(speech, permission);
    addTearDown(subject.close);
    addTearDown(mic.close);
    await tester.pumpLocalized(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: subject),
          BlocProvider.value(value: mic),
        ],
        child: ExercisePage(
          onExit: () {},
          onFinished: (_) {},
          onExplain: (_) {},
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

  Future<ExerciseCubit> pump(
    WidgetTester tester, {
    required Exercise exercise,
    Locale locale = const Locale('ar'),
    Size size = defaultViewport,
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpAll(
    tester,
    exercises: [exercise, all.first],
    locale: locale,
    size: size,
    themeMode: themeMode,
  );

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Clips that play by themselves end by their own timer.
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> check(WidgetTester tester) async {
    await tester.tap(find.text('lesson_check'.tr()));
    await tester.pump();
    await tester.settleEntrance(_settled);
  }

  group('translating', () {
    testWidgets('says the Arabic, and another right form is shown', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<TranslationExercise>(),
      );
      expect(find.text('أذهب إلى العمل بالحافلة كل يوم.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'i take the bus to work every day',
      );
      await tester.pump();
      await check(tester);

      expect(subject.state.evaluation?.correct, isTrue);
      expect(find.text('lesson_fb_other_translation'.tr()), findsOneWidget);
      expect(lessons.attempts.single.draft, isA<TextDraft>());
      await leave(tester);
    });

    testWidgets('a wrong one shows the whole answer and why', (tester) async {
      await pump(tester, exercise: first<TranslationExercise>());

      await tester.enterText(find.byType(TextField), 'I walk to work.');
      await tester.pump();
      await check(tester);

      expect(find.text('lesson_fb_wrong'.tr()), findsOneWidget);
      expect(
        find.textContaining(
          'I go to work by bus every day.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await leave(tester);
    });
  });

  group('correcting a mistake', () {
    Finder word(String text) => find.descendant(
      of: find.byType(GestureDetector),
      matching: find.text(text),
    );

    testWidgets('the correction opens with a word, and the word moves it', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<ErrorCorrectionExercise>(),
      );
      expect(find.text('lesson_fix_choose'.tr()), findsNothing);

      await tester.tap(word('like'));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text('lesson_fix_choose'.tr()), findsOneWidget);
      expect(subject.state.canCheck, isFalse);

      await tester.tap(find.text("isn't"));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(subject.state.canCheck, isTrue);

      await tester.tap(word("don't"));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(
        subject.state.draft,
        const CorrectionDraft(tokenId: 't2'),
        reason: 'another word drops the correction',
      );
      expect(subject.state.canCheck, isFalse);
      await leave(tester);
    });

    testWidgets('right with the word and its correction together', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<ErrorCorrectionExercise>(),
      );
      await tester.tap(word("don't"));
      await tester.pump();
      await tester.settleEntrance(_settled);
      await tester.tap(find.text("doesn't"));
      await tester.pump();
      await tester.settleEntrance(_settled);
      await check(tester);

      expect(subject.state.evaluation?.correct, isTrue);
      expect(find.text('lesson_fix_choose'.tr()), findsNothing);
      expect(lessons.attempts.single.draft, isA<CorrectionDraft>());
      await leave(tester);
    });

    testWidgets('the right correction on the wrong word is wrong', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<ErrorCorrectionExercise>(),
      );
      await tester.tap(word('like'));
      await tester.pump();
      await tester.settleEntrance(_settled);
      await tester.tap(find.text("doesn't"));
      await tester.pump();
      await tester.settleEntrance(_settled);
      await check(tester);

      expect(subject.state.evaluation?.correct, isFalse);
      expect(find.text('lesson_fb_wrong'.tr()), findsOneWidget);
      await leave(tester);
    });

    test('the feedback strikes the wrong word beside its correction', () {
      final parts = correctAnswerParts(first<ErrorCorrectionExercise>());

      expect(parts.map((p) => p.text).join(), "She don't doesn't like coffee.");
      expect(parts.singleWhere((p) => p.struck).text, "don't");
      expect(parts.singleWhere((p) => p.strong).text, "doesn't");
    });
  });

  group('completing a conversation', () {
    testWidgets('the reply goes to the learner, and is checked as a choice', (
      tester,
    ) async {
      final exercise = first<DialogueExercise>();
      final subject = await pump(tester, exercise: exercise);
      expect(find.text('Are you free on Saturday?'), findsOneWidget);
      expect(find.text('Lina'), findsNWidgets(2));
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        find.bySemanticsLabel('lesson_dialogue_your_reply'.tr()),
        findsOneWidget,
      );
      semantics.dispose();

      await tester.tap(find.text('Yes, I am. Why?'));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(find.text('Yes, I am. Why?'), findsNWidgets(2));
      expect(subject.state.draft, const ChoiceDraft('a'));

      await check(tester);
      expect(subject.state.evaluation?.correct, isTrue);
      await leave(tester);
    });
  });

  group('reading', () {
    List<ReadingExercise> readings() =>
        all.whereType<ReadingExercise>().toList();

    testWidgets('each question is a step, and the text stays between them', (
      tester,
    ) async {
      final subject = await pumpAll(tester, exercises: readings(), size: _tall);
      expect(subject.state.questions, hasLength(4));
      expect(find.text('A trip to Latakia'), findsOneWidget);
      final text = tester.state(find.byType(PassageCard));
      expect(
        find.text(
          'lesson_reading_step'.tr(namedArgs: {'step': '1', 'steps': '4'}),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('By car'));
      await tester.pump();
      await check(tester);
      expect(subject.state.evaluation?.correct, isTrue);

      await tester.tap(find.text('lesson_next'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      await tester.settleEntrance(_settled);

      expect(subject.state.index, 1);
      expect(find.text('Where did they stop for lunch?'), findsOneWidget);
      expect(
        tester.state(find.byType(PassageCard)),
        same(text),
        reason: 'the text was not rebuilt, so it kept its place',
      );
      await leave(tester);
    });

    testWidgets('the whole text opens and comes back to the question', (
      tester,
    ) async {
      await pumpAll(tester, exercises: readings(), size: _tall);

      await tester.tap(find.byTooltip('lesson_reading_expand'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text('lesson_reading_back'.tr()), findsOneWidget);

      await tester.tap(find.text('lesson_reading_back'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text('lesson_reading_back'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('the whole text follows its clip while it is open', (
      tester,
    ) async {
      final subject = await pumpAll(tester, exercises: readings());

      await tester.tap(find.byTooltip('lesson_reading_expand'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);

      await tester.tap(find.text('lesson_reading_listen'.tr()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(subject.state.audio, ClipStatus.playing);
      expect(find.text('lesson_reading_stop'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a wrong answer has no clip of the whole text', (tester) async {
      await pumpAll(tester, exercises: readings(), size: _tall);

      await tester.tap(find.text('By bus'));
      await tester.pump();
      await check(tester);

      expect(find.text('lesson_fb_wrong'.tr()), findsOneWidget);
      expect(find.byTooltip('lesson_fb_listen_sentence'.tr()), findsNothing);
      await leave(tester);
    });
  });

  group('speaking an answer', () {
    Future<void> say(WidgetTester tester, String words) async {
      speech.says = words;
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump();
      speech.finish();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.settleEntrance(_settled);
    }

    testWidgets('no check button until typing', (tester) async {
      await pump(tester, exercise: first<SpeakAnswerExercise>());
      expect(find.text('lesson_check'.tr()), findsNothing);

      await tester.tap(find.byTooltip('lesson_speak_type_instead'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(find.text('lesson_check'.tr()), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text('lesson_speak_instead'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text('lesson_check'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('answered: the note, only the words sent, and done', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<SpeakAnswerExercise>(),
      );

      await say(tester, 'I usually visiting my grandparents');

      expect(find.text('lesson_fb_answered'.tr()), findsOneWidget);
      expect(find.text('A note.'), findsOneWidget);
      expect(
        find.textContaining('A better way.', findRichText: true),
        findsOneWidget,
      );
      expect(
        lessons.spokenReviews.single.draft,
        const SpokenDraft('I usually visiting my grandparents'),
      );
      expect(subject.state.done, contains(first<SpeakAnswerExercise>().id));
      expect(sounds.played, [AppSound.correct]);
      await leave(tester);
    });

    testWidgets('while judging: no verdict and no next', (tester) async {
      final gate = Completer<void>();
      lessons.reviewGate = gate.future;
      final subject = await pump(
        tester,
        exercise: first<SpeakAnswerExercise>(),
      );

      await tester.tap(find.byTooltip('lesson_speak_type_instead'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      await tester.enterText(find.byType(TextField), 'I rest at home');
      await tester.pump();
      await check(tester);

      expect(subject.state.evaluation, const ReviewPending());
      expect(find.text('lesson_fb_reviewing'.tr()), findsOneWidget);
      expect(find.text('lesson_next'.tr()), findsNothing);

      gate.complete();
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text('lesson_next'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('off topic: not counted, and another try clears it', (
      tester,
    ) async {
      lessons.spokenReview = const Ok(SpokenOffTopic(note: 'About Fridays.'));
      final subject = await pump(
        tester,
        exercise: first<SpeakAnswerExercise>(),
      );

      await say(tester, 'I like football very much');

      expect(find.text('lesson_fb_off_title'.tr()), findsOneWidget);
      expect(find.text('About Fridays.'), findsOneWidget);
      expect(find.text('lesson_fb_wrong'.tr()), findsNothing);
      expect(subject.state.done, isEmpty);
      expect(sounds.played, isEmpty);

      await tester.tap(find.text('lesson_fb_try_again'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      await tester.settleEntrance(_settled);

      expect(subject.state.evaluation, isNull);
      expect(find.text('I like'), findsNothing);
      expect(mic.state.phase, MicPhase.idle);
      await leave(tester);
    });

    testWidgets('the allowance out: said, skipped, and moving on', (
      tester,
    ) async {
      lessons.spokenReview = const Ok(ReviewQuotaOut());
      final subject = await pump(
        tester,
        exercise: first<SpeakAnswerExercise>(),
      );

      await say(tester, 'I rest');

      expect(find.text('lesson_fb_quota'.tr()), findsOneWidget);
      expect(find.text('lesson_next'.tr()), findsOneWidget);
      expect(subject.state.done, hasLength(1));
      await leave(tester);
    });

    testWidgets('no server: judged later, not wrong', (tester) async {
      lessons.spokenReview = const Err(NetworkFailure());
      final subject = await pump(
        tester,
        exercise: first<SpeakAnswerExercise>(),
      );

      await say(tester, 'I rest');

      expect(subject.state.evaluation, const ReviewLater());
      expect(find.text('lesson_fb_later'.tr()), findsOneWidget);
      expect(find.text('lesson_fb_wrong'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('cannot speak now: skips it with the other speech', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<SpeakAnswerExercise>(),
      );

      await tester.tap(find.text('lesson_mic_cant'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(subject.state.speechOff, isTrue);
      expect(subject.state.index, 1);
      await leave(tester);
    });
  });

  testLayouts('every advanced template fits', (tester, layout) async {
    for (final exercise in [
      first<TranslationExercise>(),
      first<ErrorCorrectionExercise>(),
      first<DialogueExercise>(),
      first<ReadingExercise>(),
      first<SpeakAnswerExercise>(),
    ]) {
      lessons.saved.clear();
      await pump(
        tester,
        exercise: exercise,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);
      await leave(tester);
    }
  });

  testLayouts('a text with its wrong answer sheet fits', (
    tester,
    layout,
  ) async {
    final subject = await pump(
      tester,
      exercise: first<ReadingExercise>(),
      locale: layout.locale,
      size: layout.size,
      themeMode: layout.themeMode,
    );
    subject.updateDraft(const ChoiceDraft('a'));
    await tester.pump();
    await check(tester);

    expect(tester.takeException(), isNull);
    await leave(tester);
  });
}
