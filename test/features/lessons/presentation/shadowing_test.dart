import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/reader_model.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/shadowing/cubit/shadowing_cubit.dart';
import 'package:englizia/features/lessons/presentation/shadowing/pages/shadowing_page.dart';
import 'package:englizia/features/lessons/presentation/shadowing/widgets/shadowing_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 1);

ReaderContent _read(String path) => readerFromJson(
  asJsonMap(ApiClient.unwrap(jsonDecode(File(path).readAsStringSync()))),
)!;

final _text = _read(LessonFakeDataSource.textAsset);
final _video = _read(LessonFakeDataSource.videoAsset);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;
  late FakeVideoEngine engine;

  final practised = [
    for (final sentence in _text.sentences)
      if (sentence.shadowing) sentence,
  ];

  setUp(() {
    lessons = FakeLessonRepository(exercises: const [])..reader = _text;
    engine = FakeVideoEngine();
  });

  ShadowingCubit cubit() {
    final subject = ShadowingCubit(lessons, engine, lessonId: 'les');
    addTearDown(subject.close);
    return subject;
  }

  String sentence(int i) => practised[i].english;

  group('the sentences', () {
    test('only those chosen for shadowing, the first said at once', () async {
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.ready);
      expect(subject.state.order, hasLength(practised.length));
      expect(subject.state.sentence, practised.first);
      expect(subject.state.mode, ShadowingMode.repeat);
      expect(subject.state.modelRun, isNotNull);
      expect(engine.opened.single.url, _text.audioUrl);
      expect(engine.opened.single.from, practised.first.start);
    });

    test('a lesson with none to practise says so', () async {
      lessons.reader = ReaderContent(
        duration: _text.duration,
        sentences: [
          for (final s in _text.sentences)
            ReaderSentence(id: s.id, words: s.words, arabic: s.arabic),
        ],
      );
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.failure);
    });

    test('with the model, nothing is said before the microphone', () async {
      lessons.prefs = const ReaderPrefs(shadowingMode: ShadowingMode.together);
      final subject = cubit();
      await subject.start();

      expect(subject.state.together, isTrue);
      expect(engine.opened, isEmpty);

      final length = subject.startTogether();
      await Future<void>.delayed(Duration.zero);
      expect(engine.opened, hasLength(1));
      expect(length, practised.first.end - practised.first.start);
    });

    test('a video\'s sentence plays from its moment in the video', () async {
      lessons.reader = _video;
      final subject = cubit();
      await subject.start();

      expect(subject.state.mode, ShadowingMode.together);
      subject.startTogether();
      await Future<void>.delayed(Duration.zero);
      final first = _video.sentences.firstWhere((s) => s.shadowing);
      expect(engine.opened.single.from, first.start);
    });

    test('the model at three quarters lasts longer', () async {
      final subject = cubit();
      await subject.start();

      await subject.setSpeed(ShadowingCubit.slow);
      await subject.playModel();

      expect(
        subject.state.modelRun?.length,
        (practised.first.end - practised.first.start) * (1 / .75),
      );
      expect(engine.speeds, [ShadowingCubit.slow]);
    });

    test('the words heard, and better than the try before', () async {
      final subject = cubit();
      await subject.start();
      final words = practised.first.words;

      subject.heard(
        '${words[0].text} ${words[1].text}',
        length: const Duration(seconds: 2),
      );
      expect(subject.state.attempt?.count, 2);
      expect(subject.state.improvement, isNull);
      expect(subject.state.modelRun, isNull);

      subject
        ..retry()
        ..heard(sentence(0), length: const Duration(seconds: 2));
      expect(subject.state.attempt?.count, words.length);
      expect(subject.state.improvement, (2, words.length));
    });

    test('no better, no line', () async {
      final subject = cubit();
      await subject.start();

      subject
        ..heard(sentence(0), length: Duration.zero)
        ..retry()
        ..heard('', length: Duration.zero);

      expect(subject.state.improvement, isNull);
    });

    test('«قارن»: the try, then the model', () async {
      final subject = cubit();
      await subject.start();
      subject.heard(sentence(0), length: const Duration(milliseconds: 50));

      subject.compare();
      expect(subject.state.compare?.part, ComparePart.you);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(subject.state.compare?.part, ComparePart.model);
    });

    test('a new way starts the sentence over, and is kept', () async {
      final subject = cubit();
      await subject.start();
      subject.heard(sentence(0), length: Duration.zero);

      await subject.setMode(ShadowingMode.hidden);

      expect(subject.state.attempt, isNull);
      expect(subject.state.counts, isEmpty);
      expect(lessons.prefs.shadowingMode, ShadowingMode.hidden);
    });

    test('moving on keeps the best, and the last one finishes', () async {
      final subject = cubit();
      await subject.start();
      subject
        ..heard(sentence(0), length: Duration.zero)
        ..retry()
        ..heard('', length: Duration.zero);

      subject.next();

      final best = lessons.shadowingScores.single;
      expect(best.sentenceId, practised.first.id);
      expect(best.heard, practised.first.words.length);
      expect(subject.state.at, 1);
      expect(subject.state.attempt, isNull);

      for (var i = 1; i < practised.length; i++) {
        subject.next();
      }
      expect(subject.state.finished, isTrue);
      expect(lessons.shadowingScores, hasLength(1));
    });
  });

  group('waves', () {
    test('levels spread over the bars, the loudest of each', () {
      final bars = barsOf([for (var i = 0; i < 88; i++) i.isEven ? .2 : .8]);
      expect(bars, hasLength(waveBars));
      expect(bars.every((bar) => bar == .8), isTrue);
      expect(barsOf(const []).every((bar) => bar == 0), isTrue);
    });

    test('the model\'s comes from its words when the server sends none', () {
      final bars = modelBars(practised.first);
      expect(bars, hasLength(waveBars));
      expect(bars.any((bar) => bar > 0), isTrue);
    });
  });

  group('page', () {
    late FakeSpeechListener listener;
    late FakeMicPermission permission;
    var done = 0;
    var skipped = 0;

    setUp(() {
      listener = FakeSpeechListener();
      permission = FakeMicPermission();
      done = 0;
      skipped = 0;
    });

    Future<ShadowingCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      String? practiceFrom,
    }) async {
      final subject = cubit();
      final mic = MicCubit(listener, permission);
      addTearDown(mic.close);
      await tester.pumpLocalized(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: subject),
            BlocProvider.value(value: mic),
          ],
          child: ShadowingPage(
            onExit: () {},
            onDone: () => done++,
            onSkip: () => skipped++,
            practiceFrom: practiceFrom,
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await tester.pump();
      await tester.settleEntrance(_settled);
      return subject;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(_settled);
    }

    Future<void> leave(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }

    Future<void> say(WidgetTester tester, String words) async {
      listener.says = words;
      await tester.tap(find.bySemanticsLabel('lesson_mic_press'.tr()).first);
      await tester.pump();
      listener.onLevel?.call(.6);
      listener.finish();
      await settle(tester);
    }

    Finder said(String text) => find.text(text);

    testWidgets('the sentence, its translation, the model and the way', (
      tester,
    ) async {
      await pump(tester);

      expect(said(practised.first.words.first.text), findsOneWidget);
      expect(said(practised.first.arabic), findsOneWidget);
      expect(said('shadow_listen_model'.tr()), findsOneWidget);
      expect(said('shadow_mode_repeat_hint'.tr()), findsOneWidget);
      expect(
        said('shadow_counter'.tr(namedArgs: {'at': '1', 'of': '2'})),
        findsOneWidget,
      );
      expect(said('lesson_mic_cant'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a try shows the words heard, «قارن» and the way on', (
      tester,
    ) async {
      final subject = await pump(tester);
      await tester.pump(const Duration(seconds: 6));

      await say(tester, practised.first.words.first.text);

      expect(subject.state.attempt?.count, 1);
      expect(said('shadow_compare'.tr()), findsOneWidget);
      expect(said('shadow_retry'.tr()), findsOneWidget);
      expect(said('shadow_next'.tr()), findsOneWidget);

      await tester.tap(said('shadow_compare'.tr()));
      await settle(tester);
      expect(said('shadow_you'.tr()), findsOneWidget);
      expect(said('shadow_model'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('every word heard: the guide, and the last leads on', (
      tester,
    ) async {
      final subject = await pump(tester);
      await tester.pump(const Duration(seconds: 6));
      subject.next();
      await settle(tester);
      await tester.pump(const Duration(seconds: 6));

      await say(tester, sentence(1));

      expect(said('shadow_all_heard'.tr()), findsOneWidget);
      await tester.tap(said('shadow_to_exercises'.tr()));
      await settle(tester);
      expect(done, 1);
      await leave(tester);
    });

    testWidgets('«أعد المحاولة» brings the microphone back', (tester) async {
      final subject = await pump(tester);
      await tester.pump(const Duration(seconds: 6));
      await say(tester, 'nothing alike');

      await tester.tap(said('shadow_retry'.tr()));
      await settle(tester);

      expect(subject.state.attempt, isNull);
      expect(find.bySemanticsLabel('lesson_mic_press'.tr()), findsWidgets);
      await leave(tester);
    });

    testWidgets('without the text, bars until the try', (tester) async {
      lessons.prefs = const ReaderPrefs(shadowingMode: ShadowingMode.hidden);
      await pump(tester);

      expect(find.byType(HiddenWords), findsOneWidget);
      expect(said(practised.first.arabic), findsNothing);
      expect(said('shadow_start_together'.tr()), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('lesson_mic_press'.tr()).first);
      await tester.pump();
      expect(find.byType(LiveWave), findsOneWidget);

      listener
        ..says = sentence(0)
        ..finish();
      await settle(tester);
      expect(find.byType(HiddenWords), findsNothing);
      expect(said(practised.first.arabic), findsOneWidget);
      await leave(tester);
    });

    testWidgets('with the model, the headphones note, until dismissed', (
      tester,
    ) async {
      lessons.prefs = const ReaderPrefs(shadowingMode: ShadowingMode.together);
      final subject = await pump(tester);

      expect(said('shadow_headphones'.tr()), findsOneWidget);
      await tester.tap(said('shadow_headphones_skip'.tr()));
      await settle(tester);

      expect(said('shadow_headphones'.tr()), findsNothing);
      expect(subject.state.headphonesSeen, isTrue);
      await leave(tester);
    });

    testWidgets('picking a way changes the hint and starts over', (
      tester,
    ) async {
      final subject = await pump(tester);

      await tester.tap(find.bySemanticsLabel('shadow_mode_together'.tr()));
      await settle(tester);

      expect(subject.state.mode, ShadowingMode.together);
      expect(said('shadow_mode_together_hint'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('heard nothing: the note, and no try counted', (tester) async {
      final subject = await pump(tester);
      await tester.pump(const Duration(seconds: 6));

      await say(tester, '');

      expect(said('lesson_mic_not_heard'.tr()), findsOneWidget);
      expect(subject.state.counts, isEmpty);
      await leave(tester);
    });

    testWidgets('the microphone refused: the settings, or skipping it all', (
      tester,
    ) async {
      permission.access = MicAccess.denied;
      await pump(tester);
      await tester.pump(const Duration(seconds: 6));

      await tester.tap(find.bySemanticsLabel('lesson_mic_press'.tr()).first);
      await settle(tester);

      expect(said('lesson_mic_open_settings'.tr()), findsOneWidget);
      await tester.tap(said('shadow_skip'.tr()));
      expect(skipped, 1);
      await leave(tester);
    });

    testWidgets('«لا أستطيع التحدث الآن» skips the step', (tester) async {
      await pump(tester);

      await tester.tap(said('lesson_mic_cant'.tr()));

      expect(skipped, 1);
      await leave(tester);
    });

    testWidgets('from «تدرّب», the lesson it came from and the next sentence', (
      tester,
    ) async {
      await pump(tester, practiceFrom: 'Farm');
      await tester.pump(const Duration(seconds: 6));

      expect(said('shadow_title'.tr()), findsOneWidget);
      expect(
        said('shadow_from'.tr(namedArgs: {'title': 'Farm'})),
        findsOneWidget,
      );

      await say(tester, sentence(0));
      expect(said('shadow_next_sentence'.tr()), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a video\'s sentence shows its frame', (tester) async {
      lessons
        ..reader = _video
        ..prefs = const ReaderPrefs(shadowingMode: ShadowingMode.repeat);
      await pump(tester);

      expect(find.bySemanticsLabel('shadow_video_frame'.tr()), findsOneWidget);
      await leave(tester);
    });

    testLayouts('every way and the result fit', (tester, layout) async {
      for (final mode in ShadowingMode.values) {
        lessons.prefs = ReaderPrefs(shadowingMode: mode);
        engine = FakeVideoEngine();
        listener = FakeSpeechListener();
        final subject = await pump(
          tester,
          locale: layout.locale,
          size: layout.size,
          themeMode: layout.themeMode,
        );
        expect(tester.takeException(), isNull);
        subject
          ..heard('Sara', length: const Duration(seconds: 1))
          ..compare();
        await settle(tester);
        expect(tester.takeException(), isNull);
        await leave(tester);
      }
    });
  });
}
