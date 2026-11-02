import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/pages/exercise_page.dart';
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
  late FakeSpeechListener speech;
  late FakeMicPermission permission;
  late FakeSoundPlayer sounds;
  late MicCubit mic;
  late List<Exercise> all;

  setUp(() {
    all = sampleExercises();
    lessons = FakeLessonRepository(exercises: all);
    speech = FakeSpeechListener();
    permission = FakeMicPermission();
    sounds = FakeSoundPlayer();
  });

  T first<T extends Exercise>() => all.whereType<T>().first;

  Future<ExerciseCubit> pump(
    WidgetTester tester, {
    required Exercise exercise,
    Exercise? then,
    Locale locale = const Locale('ar'),
    Size size = defaultViewport,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    lessons.exercises = [exercise, ?then, all.first];
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
          onExplain: () {},
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
    // Clips that play by themselves end by their own timer.
    await tester.pump(const Duration(seconds: 5));
  }

  /// Says what [speech] was told to, through to the sheet.
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

  group('repeating a sentence', () {
    testWidgets('no check button: the end of the recording is the check', (
      tester,
    ) async {
      await pump(tester, exercise: first<RepeatSentenceExercise>());

      expect(find.text('lesson_check'.tr()), findsNothing);
      expect(find.text('lesson_mic_press'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('heard enough: well done, sent, with the words counted', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<RepeatSentenceExercise>(),
      );

      await say(tester, 'Sara feeds the chickens school');

      expect(subject.state.evaluation?.correct, isTrue);
      expect(find.text('lesson_fb_well_done'.tr()), findsOneWidget);
      expect(lessons.attempts.single.draft, isA<SpeechDraft>());
      expect(sounds.played, [AppSound.correct]);
      await leave(tester);
    });

    testWidgets('heard too little: neutral, nothing sent, and a new try', (
      tester,
    ) async {
      final subject = await pump(
        tester,
        exercise: first<RepeatSentenceExercise>(),
      );

      await say(tester, 'Sara school');

      expect(find.text('lesson_fb_try_title'.tr()), findsOneWidget);
      expect(find.text('lesson_fb_wrong'.tr()), findsNothing);
      expect(lessons.attempts, isEmpty);
      expect(sounds.played, isEmpty);
      expect(subject.state.done, isEmpty);

      await tester.tap(find.text('lesson_fb_try_again'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      await tester.settleEntrance(_settled);

      expect(subject.state.evaluation, isNull);
      expect(subject.state.draft, isNull);
      expect(mic.state.phase, MicPhase.idle);
      await leave(tester);
    });

    testWidgets('skipping moves on, counted nowhere', (tester) async {
      final subject = await pump(
        tester,
        exercise: first<RepeatSentenceExercise>(),
      );
      await say(tester, 'Sara');

      await tester.tap(find.text('lesson_fb_skip'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      await tester.settleEntrance(_settled);

      expect(subject.state.index, 1);
      expect(lessons.attempts, isEmpty);
      await leave(tester);
    });

    testWidgets('silence: not an attempt, and ready again', (tester) async {
      final subject = await pump(
        tester,
        exercise: first<RepeatSentenceExercise>(),
      );

      await say(tester, '');

      expect(find.text('lesson_mic_not_heard'.tr()), findsOneWidget);
      expect(subject.state.draft, isNull);
      expect(mic.state.phase, MicPhase.notHeard);
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump();
      expect(mic.state.phase, MicPhase.listening);
      speech.finish();
      await tester.pump();
      await leave(tester);
    });

    testWidgets('a phone with no engine reads as not heard', (tester) async {
      await pump(tester, exercise: first<RepeatSentenceExercise>());
      speech.says = null;

      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump();
      speech.finish();
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(mic.state.phase, MicPhase.notHeard);
      await leave(tester);
    });

    testWidgets('the press that stops it ends the listening', (tester) async {
      await pump(tester, exercise: first<RepeatSentenceExercise>());
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump();
      expect(mic.state.phase, MicPhase.listening);
      expect(find.text('lesson_mic_press'.tr()), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      expect(mic.state.seconds, 3);
      expect(find.text('0:03'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.stop_rounded).last);
      await tester.pump();
      expect(speech.stops, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.settleEntrance(_settled);
      await leave(tester);
    });

    testWidgets('«لا أستطيع» skips the speech questions of this lesson only', (
      tester,
    ) async {
      final repeat = first<RepeatSentenceExercise>();
      final subject = await pump(tester, exercise: repeat, then: repeat);

      await tester.tap(find.text('lesson_mic_cant'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(subject.state.question, all.first);
      expect(lessons.attempts, isEmpty);
      expect(lessons.saved['les']?.done ?? const <String>{}, isEmpty);
      await leave(tester);
    });

    group('the permission', () {
      testWidgets('the first time, why comes first, then the system', (
        tester,
      ) async {
        permission.access = MicAccess.notAsked;
        await pump(tester, exercise: first<RepeatSentenceExercise>());

        await tester.tap(find.byIcon(Icons.mic_rounded));
        await tester.pump();
        await tester.settleEntrance(_settled);
        expect(find.text('lesson_mic_why_title'.tr()), findsOneWidget);
        expect(permission.requests, 0);

        await tester.tap(find.text('lesson_mic_why_continue'.tr()));
        await tester.pump();
        await tester.settleEntrance(_settled);

        expect(permission.requests, 1);
        expect(mic.state.phase, MicPhase.listening);
        speech.finish();
        await tester.pump();
        await leave(tester);
      });

      testWidgets('the scrim asks nothing', (tester) async {
        permission.access = MicAccess.notAsked;
        await pump(tester, exercise: first<RepeatSentenceExercise>());
        await tester.tap(find.byIcon(Icons.mic_rounded));
        await tester.pump();
        await tester.settleEntrance(_settled);

        await tester.tapAt(const Offset(20, 40));
        await tester.pump();
        await tester.settleEntrance(_settled);

        expect(permission.requests, 0);
        expect(mic.state.phase, MicPhase.idle);
        await leave(tester);
      });

      testWidgets('refused: the card, the settings and a way past', (
        tester,
      ) async {
        permission
          ..access = MicAccess.notAsked
          ..answer = MicAccess.denied;
        final subject = await pump(
          tester,
          exercise: first<RepeatSentenceExercise>(),
        );
        await tester.tap(find.byIcon(Icons.mic_rounded));
        await tester.pump();
        await tester.settleEntrance(_settled);
        await tester.tap(find.text('lesson_mic_why_continue'.tr()));
        await tester.pump();
        await tester.settleEntrance(_settled);

        expect(find.text('lesson_mic_denied'.tr()), findsOneWidget);

        await tester.tap(find.text('lesson_mic_open_settings'.tr()));
        await tester.pump();
        expect(permission.settingsOpened, 1);

        await tester.tap(find.text('lesson_mic_skip_speech'.tr()));
        await tester.pump();
        await tester.settleEntrance(_settled);
        expect(subject.state.speechOff, isTrue);
        expect(subject.state.index, 1);
        await leave(tester);
      });

      testWidgets('already refused: straight to the card', (tester) async {
        permission.access = MicAccess.denied;
        await pump(tester, exercise: first<RepeatSentenceExercise>());

        await tester.tap(find.byIcon(Icons.mic_rounded));
        await tester.pump();
        await tester.settleEntrance(_settled);

        expect(find.text('lesson_mic_why_title'.tr()), findsNothing);
        expect(find.text('lesson_mic_denied'.tr()), findsOneWidget);
        await leave(tester);
      });

      test('allowed in the settings, the microphone comes back', () async {
        permission.access = MicAccess.denied;
        final cubit = MicCubit(speech, permission)..showDenied();
        addTearDown(cubit.close);

        await cubit.recheck();
        expect(cubit.state.phase, MicPhase.denied);

        permission.access = MicAccess.granted;
        await cubit.recheck();
        expect(cubit.state.phase, MicPhase.idle);
      });
    });
  });

  group('writing what you hear', () {
    Future<ExerciseCubit> typed(WidgetTester tester, String text) async {
      final subject = await pump(
        tester,
        exercise: first<ListenWriteExercise>(),
      );
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      return subject;
    }

    Future<void> check(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(AppButton, 'lesson_check'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
    }

    testWidgets('checking waits for something written', (tester) async {
      final subject = await typed(tester, '   ');

      expect(subject.state.canCheck, isFalse);
      await leave(tester);
    });

    testWidgets('the keyboard helps with nothing', (tester) async {
      await pump(tester, exercise: first<ListenWriteExercise>());

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.textCapitalization, TextCapitalization.none);
      await leave(tester);
    });

    testWidgets('a letter out in a long word is right, with a note', (
      tester,
    ) async {
      final subject = await typed(tester, 'We usually eat diner at seven');

      await check(tester);

      expect(subject.state.evaluation?.correct, isTrue);
      expect(find.text('lesson_fb_spelling'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('another accepted form is right, and the first is shown', (
      tester,
    ) async {
      await typed(tester, 'we usually eat dinner at 7');

      await check(tester);

      expect(find.text('lesson_fb_other_form'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('wrong: the right sentence', (tester) async {
      final subject = await typed(tester, 'We eat at seven');

      await check(tester);

      expect(subject.state.evaluation?.correct, isFalse);
      expect(find.text('lesson_fb_right_answer'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('locked once checked', (tester) async {
      await typed(tester, 'We eat at seven');
      await check(tester);

      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await leave(tester);
    });
  });

  group('typing into the blank', () {
    testWidgets('the keyboard opens by itself, and Enter checks', (
      tester,
    ) async {
      final subject = await pump(tester, exercise: first<FillTypedExercise>());

      expect(find.textContaining('(go)'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus, isTrue);

      await tester.enterText(find.byType(TextField), 'goes');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(subject.state.evaluation?.correct, isTrue);
      expect(field.focusNode?.hasFocus, isFalse);
      await leave(tester);
    });

    testWidgets('a letter out is wrong here: it is the rule itself', (
      tester,
    ) async {
      final subject = await pump(tester, exercise: first<FillTypedExercise>());

      await tester.enterText(find.byType(TextField), 'gos');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(subject.state.evaluation?.correct, isFalse);
      await leave(tester);
    });

    testWidgets('nothing typed, Enter does nothing', (tester) async {
      final subject = await pump(tester, exercise: first<FillTypedExercise>());

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(subject.state.checked, isFalse);
      await leave(tester);
    });
  });

  group('ordering sentences', () {
    Future<void> place(WidgetTester tester, String text) async {
      await tester.tap(find.text(text).last);
      await tester.pump();
      await tester.settleEntrance(_settled);
    }

    testWidgets('a sentence goes to the first empty place, and back', (
      tester,
    ) async {
      final exercise = first<SentenceOrderExercise>();
      final subject = await pump(tester, exercise: exercise);

      await place(tester, exercise.sentences.first);
      final slots = subject.state.draft! as SlotsDraft;
      expect(slots.chips.first?.text, exercise.sentences.first);

      await tester.tap(find.text(exercise.sentences.first).first);
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect((subject.state.draft! as SlotsDraft).chips.first, isNull);
      await leave(tester);
    });

    testWidgets('all placed, it can be checked; each place has its verdict', (
      tester,
    ) async {
      final exercise = first<SentenceOrderExercise>();
      final subject = await pump(tester, exercise: exercise);
      final order = [
        exercise.sentences[1],
        exercise.sentences[0],
        exercise.sentences[2],
        exercise.sentences[3],
      ];

      for (final sentence in order) {
        await place(tester, sentence);
      }
      expect(subject.state.canCheck, isTrue);

      await tester.tap(find.widgetWithText(AppButton, 'lesson_check'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(
        subject.state.evaluation,
        const SlotsEvaluation([false, false, true, true]),
      );
      await leave(tester);
    });
  });

  group('spelling', () {
    Future<void> letter(WidgetTester tester, String text) async {
      await tester.tap(find.text(text).last);
      await tester.pump();
      await tester.settleEntrance(_settled);
    }

    testWidgets('letters go to the first empty place, in order', (
      tester,
    ) async {
      final subject = await pump(tester, exercise: first<SpellingExercise>());

      for (final text in ['b', 'a', 'r', 'n']) {
        await letter(tester, text);
      }

      expect(
        (subject.state.draft! as SlotsDraft).chips.map((c) => c?.text).join(),
        'barn',
      );
      await subject.check();
      await tester.settleEntrance(_settled);
      expect(subject.state.evaluation?.correct, isTrue);
      await leave(tester);
    });

    testWidgets('a letter placed goes back with a tap', (tester) async {
      final subject = await pump(tester, exercise: first<SpellingExercise>());
      await letter(tester, 'e');

      await tester.tap(
        find.bySemanticsLabel(
          'lesson_letter'.tr(namedArgs: {'number': '1', 'letter': 'e'}),
        ),
      );
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect((subject.state.draft! as SlotsDraft).chips.first, isNull);
      await leave(tester);
    });

    testWidgets('a wrong letter is marked, and the word shown', (tester) async {
      final subject = await pump(tester, exercise: first<SpellingExercise>());
      for (final text in ['b', 'e', 'r', 'n']) {
        await letter(tester, text);
      }

      await subject.check();
      await tester.settleEntrance(_settled);

      expect(
        subject.state.evaluation,
        const SlotsEvaluation([true, false, true, true]),
      );
      expect(find.text('lesson_fb_right_answer'.tr()), findsOneWidget);
      await leave(tester);
    });
  });

  testLayouts('every produce template fits', (tester, layout) async {
    for (final exercise in all.where(
      (e) =>
          e is RepeatSentenceExercise ||
          e is TypedExercise ||
          e is SentenceOrderExercise ||
          e is SpellingExercise,
    )) {
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

  testWidgets('under reduce motion the words simply show', (tester) async {
    lessons.exercises = [first<RepeatSentenceExercise>(), all.first];
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
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: subject),
            BlocProvider.value(value: mic),
          ],
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

    await say(tester, 'Sara feeds the chickens before school');

    expect(subject.state.evaluation?.correct, isTrue);
    expect(tester.takeException(), isNull);
    await leave(tester);
  });
}
