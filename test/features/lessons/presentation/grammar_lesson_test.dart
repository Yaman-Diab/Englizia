import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:englizia/features/lessons/domain/entities/teacher_question.dart';
import 'package:englizia/features/lessons/domain/repositories/teacher_question_repository.dart';
import 'package:englizia/features/lessons/domain/services/watch_progress.dart';
import 'package:englizia/features/lessons/presentation/grammar/cubit/grammar_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/grammar/cubit/teacher_questions_cubit.dart';
import 'package:englizia/features/lessons/presentation/grammar/pages/grammar_lesson_page.dart';
import 'package:englizia/features/lessons/presentation/grammar/widgets/grammar_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 1);

const _summary = RuleSummary(
  text: 'the rule',
  rows: [
    RuleRow(
      left: 'he / she / it',
      right: [RulePart('play'), RulePart('s', marked: true)],
    ),
  ],
  examples: [
    RuleExample(
      parts: [RulePart('She '), RulePart('works', strong: true)],
      arabic: 'in Arabic',
      audioUrl: 'https://example.com/a.mp3',
    ),
  ],
);

const _video = GrammarVideo(
  id: 'v1',
  duration: Duration(seconds: 100),
  sources: [
    VideoSource(quality: VideoQuality.auto, url: 'auto.m3u8'),
    VideoSource(quality: VideoQuality.low, url: 'low.mp4', sizeMb: 15),
  ],
  captions: [
    VideoCaption(
      from: Duration.zero,
      to: Duration(seconds: 10),
      text: 'the first line',
    ),
  ],
);

const _content = GrammarContent(
  summary: _summary,
  requiredPercent: 80,
  video: _video,
  teacherName: 'The teacher',
  questionsEnabled: true,
);

VideoSnapshot _at(int seconds, {bool playing = true, bool buffering = false}) =>
    VideoSnapshot(
      position: Duration(seconds: seconds),
      duration: const Duration(seconds: 100),
      playing: playing,
      buffering: buffering,
      ready: true,
    );

class _FakeQuestions implements TeacherQuestionRepository {
  List<TeacherQuestion> questions = const [];
  Result<TeacherQuestion>? answer;
  final asked = <TeacherQuestion>[];
  var ids = 0;

  @override
  Future<Result<List<TeacherQuestion>>> list(String lessonId) async =>
      Ok(questions);

  @override
  String newQuestionId() => 'id${ids++}';

  @override
  Future<Result<TeacherQuestion>> ask(
    String lessonId,
    TeacherQuestion question,
  ) async {
    asked.add(question);
    return answer ?? Ok(question.withStatus(QuestionStatus.sent));
  }
}

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;
  late FakeVideoEngine engine;
  late FakeClipPlayer clips;

  setUp(() {
    lessons = FakeLessonRepository(exercises: const [])..grammar = _content;
    engine = FakeVideoEngine();
    clips = FakeClipPlayer();
  });

  GrammarLessonCubit cubit() {
    final subject = GrammarLessonCubit(lessons, engine, clips, lessonId: 'les');
    addTearDown(subject.close);
    return subject;
  }

  Future<void> report(FakeVideoEngine e, VideoSnapshot snapshot) async {
    e.report(snapshot);
    await Future<void>.delayed(Duration.zero);
  }

  /// Plays from where it is to [to], one second at a time, as a player reports.
  Future<void> watchTo(GrammarLessonCubit subject, int from, int to) async {
    for (var s = from; s <= to; s++) {
      await report(engine, _at(s));
    }
  }

  group('what was really watched', () {
    test('counts the seconds that played, once each', () {
      final watch = WatchProgress(const Duration(seconds: 10))
        ..watched(Duration.zero, const Duration(seconds: 3))
        ..watched(Duration.zero, const Duration(seconds: 3));

      expect(watch.seconds, 3);
      expect(watch.percent, 30);
      expect(watch.reached(30), isTrue);
      expect(watch.reached(31), isFalse);
    });

    test('keeps its parts as ranges, and reads them back', () {
      final watch = WatchProgress(const Duration(seconds: 10))
        ..watched(Duration.zero, const Duration(seconds: 2))
        ..watched(const Duration(seconds: 5), const Duration(seconds: 7));

      expect(watch.ranges, [(0, 2), (5, 7)]);
      expect(
        WatchProgress(
          const Duration(seconds: 10),
          ranges: watch.ranges,
        ).seconds,
        4,
      );
    });

    test('never counts past the end, and a video of no length is nothing', () {
      final watch = WatchProgress(const Duration(seconds: 2))
        ..watched(Duration.zero, const Duration(seconds: 9));

      expect(watch.seconds, 2);
      expect(WatchProgress(Duration.zero).percent, 0);
      expect(WatchProgress(Duration.zero).reached(0), isFalse);
    });
  });

  group('the session', () {
    test('nothing plays by itself', () async {
      final subject = cubit();
      await subject.start();

      expect(subject.state.stage, VideoStage.cover);
      expect(engine.opened, isEmpty);
      expect(subject.state.unlocked, isFalse);
    });

    test('dragging to the end counts for nothing', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await watchTo(subject, 0, 5);

      await subject.seekTo(const Duration(seconds: 95));
      await report(engine, _at(95));
      await report(engine, _at(96));

      expect(subject.state.unlocked, isFalse);
      expect(subject.state.watchedPercent, 6);
    });

    test('a jump the player reports by itself is no watching', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await report(engine, _at(0));
      await report(engine, _at(90));

      expect(subject.state.watchedPercent, 0);
    });

    test('paused or loading, the time does not count', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await report(engine, _at(0));
      await report(engine, _at(2, playing: false));
      await report(engine, _at(4, buffering: true));

      expect(subject.state.watchedPercent, 0);
    });

    test('enough opens the exercises, says so and tells the server', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await watchTo(subject, 0, 79);
      expect(subject.state.unlocked, isFalse);

      await watchTo(subject, 79, 80);

      expect(subject.state.unlocked, isTrue);
      expect(subject.state.celebrating, isTrue);
      expect(lessons.watchesSent, isNotEmpty);
    });

    test('where it stopped is offered, from this phone first', () async {
      lessons.watches['les'] = const WatchState(
        videoId: 'v1',
        positionSeconds: 34,
        ranges: [(0, 34)],
      );
      final subject = cubit();
      await subject.start();

      expect(subject.state.resumeFrom, const Duration(seconds: 34));
      expect(subject.state.watchedPercent, 34);

      await subject.play();
      expect(engine.opened.single.from, const Duration(seconds: 34));
      expect(subject.state.resumeFrom, isNull);
    });

    test('from the start starts over, keeping what was watched', () async {
      lessons.watches['les'] = const WatchState(
        videoId: 'v1',
        positionSeconds: 34,
        ranges: [(0, 34)],
      );
      final subject = cubit();
      await subject.start();

      await subject.playFromStart();

      expect(engine.opened.single.from, Duration.zero);
      expect(subject.state.watchedPercent, 34);
    });

    test('a replaced video starts from its beginning', () async {
      lessons.watches['les'] = const WatchState(
        videoId: 'old',
        positionSeconds: 34,
        ranges: [(0, 90)],
      );
      final subject = cubit();
      await subject.start();

      expect(subject.state.resumeFrom, isNull);
      expect(subject.state.unlocked, isFalse);
    });

    test('with no video the exercises are open from the start', () async {
      lessons.grammar = const GrammarContent(
        summary: _summary,
        requiredPercent: 80,
        bookPage: 34,
      );
      final subject = cubit();
      await subject.start();

      expect(subject.state.unlocked, isTrue);
      expect(subject.state.celebrating, isFalse);
    });

    test('when the server lets the learner on, they are on', () async {
      lessons.grammar = const GrammarContent(
        summary: _summary,
        requiredPercent: 80,
        video: _video,
        exercisesOpen: true,
      );
      final subject = cubit();
      await subject.start();

      expect(subject.state.unlocked, isTrue);
    });

    test('a lesson with no such content is a failure with a retry', () async {
      lessons.grammar = null;
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.failure);
    });

    test('a failed video stays usable, and tries again from there', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await report(engine, _at(0));
      await report(engine, _at(1));
      await report(engine, const VideoSnapshot(failed: true));
      expect(subject.state.stage, VideoStage.failed);

      await subject.retry();

      expect(subject.state.stage, VideoStage.playing);
      expect(engine.opened.last.from, const Duration(seconds: 1));
    });

    test(
      'a quality is remembered, and carries on from the same place',
      () async {
        final subject = cubit();
        await subject.start();
        await subject.play();
        await report(engine, _at(0));
        await report(engine, _at(2));

        await subject.setQuality(VideoQuality.low);

        expect(lessons.quality, VideoQuality.low);
        expect(engine.opened.last.url, 'low.mp4');
        expect(engine.opened.last.from, const Duration(seconds: 2));
      },
    );

    test('the remembered quality is the one opened', () async {
      lessons.quality = VideoQuality.low;
      final subject = cubit();
      await subject.start();
      await subject.play();

      expect(engine.opened.single.url, 'low.mp4');
    });

    test('speed goes to the player, and captions follow the time', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await subject.setSpeed(1.5);
      expect(engine.speeds, [1.5]);

      expect(subject.state.caption, isNull, reason: 'captions start off');
      subject.toggleCaptions();
      expect(subject.state.caption, 'the first line');

      await report(engine, _at(50));
      expect(subject.state.caption, isNull);
    });

    test(
      'at normal speed a longer step still counts at a faster one',
      () async {
        final subject = cubit();
        await subject.start();
        await subject.play();
        await subject.setSpeed(1.5);
        await report(engine, _at(0));
        await report(engine, _at(4));

        expect(subject.state.watchedPercent, 4);
      },
    );

    test('an example waits for the video to pause', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await report(engine, _at(0));

      await subject.sayExample(0);

      expect(engine.pauses, 1);
      expect(subject.state.saying, 0);
    });

    test('leaving keeps the place, and lets the player go', () async {
      final subject = GrammarLessonCubit(
        lessons,
        engine,
        clips,
        lessonId: 'les',
      );
      await subject.start();
      await subject.play();
      await report(engine, _at(0));
      await report(engine, _at(3));

      await subject.close();

      expect(lessons.watches['les']?.positionSeconds, 3);
      expect(lessons.watchesSent.last.positionSeconds, 3);
      expect(engine.disposed, isTrue);
    });
  });

  group('the private questions', () {
    TeacherQuestionsCubit questions(_FakeQuestions repository) {
      final subject = TeacherQuestionsCubit(repository, lessonId: 'les');
      addTearDown(subject.close);
      return subject;
    }

    test('a new one shows first, with where the video was', () async {
      final repository = _FakeQuestions();
      final subject = questions(repository);
      await subject.load();

      await subject.ask(
        '  why?  ',
        videoPosition: const Duration(minutes: 2, seconds: 14),
      );

      final asked = repository.asked.single;
      expect(asked.text, 'why?');
      expect(asked.videoPosition, const Duration(minutes: 2, seconds: 14));
      expect(subject.state.questions.single.status, QuestionStatus.sent);
    });

    test('nothing is sent for an empty one', () async {
      final repository = _FakeQuestions();
      final subject = questions(repository);
      await subject.load();

      await subject.ask('   ');

      expect(repository.asked, isEmpty);
      expect(subject.state.questions, isEmpty);
    });

    test('one that could not go stays, and goes again as the same', () async {
      final repository = _FakeQuestions()..answer = const Err(NetworkFailure());
      final subject = questions(repository);
      await subject.load();

      await subject.ask('why?');
      final failed = subject.state.questions.single;
      expect(failed.status, QuestionStatus.failed);

      repository.answer = null;
      await subject.resend(failed);

      expect(subject.state.questions, hasLength(1));
      expect(subject.state.questions.single.status, QuestionStatus.sent);
      expect(repository.asked.map((q) => q.id).toSet(), hasLength(1));
    });
  });

  group('the page', () {
    late _FakeQuestions questions;

    final mine = TeacherQuestion(
      id: 'q1',
      text: 'my own question',
      askedAt: DateTime(2026),
      videoPosition: const Duration(minutes: 2, seconds: 14),
      reply: const TeacherReply(
        name: 'The teacher',
        role: ReplierRole.teacher,
        text: 'the answer',
      ),
    );

    setUp(() => questions = _FakeQuestions());

    Future<GrammarLessonCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      VoidCallback? onStart,
      VoidCallback? onExit,
    }) async {
      final subject = cubit();
      final asking = TeacherQuestionsCubit(questions, lessonId: 'les');
      addTearDown(asking.close);
      await tester.pumpLocalized(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: subject),
            BlocProvider.value(value: asking),
          ],
          child: GrammarLessonPage(
            onStartExercises: onStart ?? () {},
            onExit: onExit ?? () {},
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await asking.load();
      await tester.pump();
      await tester.settleEntrance(_settled);
      return subject;
    }

    Future<void> leave(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 7));
    }

    testWidgets('the cover: its length, the rule, and the way to watch', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text(videoTime(_video.duration)), findsOneWidget);
      expect(find.text('lesson_gv_watch'.tr()), findsOneWidget);
      expect(find.text('lesson_gv_summary'.tr()), findsOneWidget);
      expect(find.text('the rule'), findsOneWidget);
      expect(find.text('The teacher'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('the button starts the video, not the exercises', (
      tester,
    ) async {
      var started = 0;
      await pump(tester, onStart: () => started++);

      await tester.tap(find.text('lesson_gv_watch'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(engine.opened, hasLength(1));
      expect(started, 0);
      await leave(tester);
    });

    testWidgets('the watched share shows, then the button changes', (
      tester,
    ) async {
      var started = 0;
      final subject = await pump(tester, onStart: () => started++);
      await subject.play();
      await tester.pump();
      for (var s = 0; s <= 34; s++) {
        engine.report(_at(s));
        await tester.pump();
      }
      expect(
        find.text(
          'lesson_gv_watched'.tr(
            namedArgs: {'watched': '34', 'required': '80'},
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('lesson_gv_keep_watching'.tr()), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      final fill = tester.getSize(find.byType(AnimatedFractionallySizedBox));
      expect(fill.height, greaterThan(0), reason: 'a bar with no height');
      expect(fill.width, greaterThan(0));

      for (var s = 35; s <= 80; s++) {
        engine.report(_at(s));
        await tester.pump();
      }
      await tester.settleEntrance(_settled);

      expect(find.text('lesson_gv_can_start'.tr()), findsOneWidget);
      expect(find.text('lesson_gv_watched_badge'.tr()), findsOneWidget);
      await tester.tap(find.text('lesson_gv_start'.tr()));
      await tester.pump();
      expect(started, 1);
      await leave(tester);
    });

    testWidgets('it stopped there: carry on, or from the start', (
      tester,
    ) async {
      lessons.watches['les'] = const WatchState(
        videoId: 'v1',
        positionSeconds: 134,
        ranges: [(0, 34)],
      );
      await pump(tester);

      expect(
        find.text('lesson_gv_stopped_at'.tr(namedArgs: {'time': '2:14'})),
        findsOneWidget,
      );
      await tester.tap(find.text('lesson_gv_continue'.tr()));
      await tester.pump();
      expect(
        engine.opened.single.from,
        const Duration(minutes: 2, seconds: 14),
      );
      await tester.settleEntrance(_settled);
      await leave(tester);
    });

    testWidgets('the speed sheet marks its choice and sets it', (tester) async {
      final subject = await pump(tester);
      await subject.play();
      engine.report(_at(1, playing: false));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.bySemanticsLabel(RegExp('.*1.*×')).first);
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text('lesson_gv_speed_title'.tr()), findsOneWidget);

      await tester.tap(
        find.text('lesson_gv_speed'.tr(namedArgs: {'speed': '1.5'})),
      );
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(engine.speeds, [1.5]);
      await leave(tester);
    }, semanticsEnabled: true);

    testWidgets('slow to load: a lower quality is offered after a while', (
      tester,
    ) async {
      final subject = await pump(tester);
      await subject.play();
      await tester.pump();
      expect(find.text('lesson_gv_slow'.tr()), findsNothing);

      await tester.pump(const Duration(seconds: 6));

      expect(find.text('lesson_gv_slow'.tr()), findsOneWidget);
      await tester.tap(find.text('lesson_gv_lower_quality'.tr()));
      await tester.pump();
      await tester.pump();

      expect(engine.opened.last.url, 'low.mp4');
      await leave(tester);
    });

    testWidgets('a failed video says so, and the rule stays', (tester) async {
      final subject = await pump(tester);
      await subject.play();
      engine.report(const VideoSnapshot(failed: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('lesson_gv_failed'.tr()), findsOneWidget);
      expect(find.text('the rule'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('with no video: no player, the book, and exercises open', (
      tester,
    ) async {
      var started = 0;
      lessons.grammar = const GrammarContent(
        summary: _summary,
        requiredPercent: 80,
        bookPage: 34,
      );
      await pump(tester, onStart: () => started++);

      expect(find.byType(GrammarPlayer), findsNothing);
      expect(
        find.text('lesson_gv_book_page'.tr(namedArgs: {'page': '34'})),
        findsOneWidget,
      );
      await tester.tap(find.text('lesson_gv_start'.tr()));
      await tester.pump();
      expect(started, 1);
      await leave(tester);
    });

    group('the questions under the video', () {
      testWidgets('are said to be private, and name no one else', (
        tester,
      ) async {
        questions.questions = [mine];
        await pump(tester);

        expect(find.text('lesson_q_title'.tr()), findsOneWidget);
        expect(find.text('lesson_q_private'.tr()), findsOneWidget);
        expect(find.text('lesson_q_you'.tr()), findsOneWidget);
        expect(find.text('my own question'), findsOneWidget);
        expect(find.text('the answer'), findsOneWidget);
        expect(find.text('lesson_q_role_teacher'.tr()), findsOneWidget);
        expect(find.textContaining('2:14'), findsOneWidget);
        await leave(tester);
      });

      testWidgets('an answer from the admins says so', (tester) async {
        questions.questions = [
          TeacherQuestion(
            id: 'q',
            text: 'mine',
            askedAt: DateTime(2026),
            reply: const TeacherReply(
              name: 'Support',
              role: ReplierRole.admin,
              text: 'the answer',
            ),
          ),
        ];
        await pump(tester);

        expect(find.text('lesson_q_role_admin'.tr()), findsOneWidget);
        await leave(tester);
      });

      testWidgets('not answered yet says so', (tester) async {
        questions.questions = [
          TeacherQuestion(id: 'q', text: 'mine', askedAt: DateTime(2026)),
        ];
        await pump(tester);

        expect(find.text('lesson_q_waiting'.tr()), findsOneWidget);
        await leave(tester);
      });

      testWidgets('none yet: asking is one press away, in the sheet', (
        tester,
      ) async {
        await pump(tester);

        await tester.ensureVisible(find.text('lesson_q_ask'.tr()));
        await tester.pump();
        await tester.tap(find.text('lesson_q_ask'.tr()));
        await tester.pump();
        await tester.settleEntrance(_settled);

        expect(find.text('lesson_q_empty_title'.tr()), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'why?');
        await tester.pump();
        await tester.tap(find.byTooltip('lesson_q_send'.tr()));
        await tester.pump();
        await tester.settleEntrance(_settled);

        expect(questions.asked.single.text, 'why?');
        expect(find.text('why?'), findsWidgets);
        await leave(tester);
      });

      testWidgets('send stays off until there is something to send', (
        tester,
      ) async {
        await pump(tester);
        await tester.ensureVisible(find.text('lesson_q_ask'.tr()));
        await tester.pump();
        await tester.tap(find.text('lesson_q_ask'.tr()));
        await tester.pump();
        await tester.settleEntrance(_settled);

        await tester.tap(find.byTooltip('lesson_q_send'.tr()));
        await tester.pump();

        expect(questions.asked, isEmpty);
        await leave(tester);
      });

      testWidgets('where the feature is off, there is no section', (
        tester,
      ) async {
        lessons.grammar = const GrammarContent(
          summary: _summary,
          requiredPercent: 80,
          video: _video,
        );
        await pump(tester);

        expect(find.text('lesson_q_title'.tr()), findsNothing);
        await leave(tester);
      });
    });

    testWidgets('full screen fills it and comes back with the phone back', (
      tester,
    ) async {
      final subject = await pump(tester);
      await subject.play();
      engine.report(_at(1, playing: false));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pump();
      expect(find.text('lesson_gv_summary'.tr()), findsNothing);
      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);

      tester.setViewport(const Size(800, 360));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomRight(find.byIcon(Icons.fullscreen_exit_rounded)).dy,
        lessThanOrEqualTo(360),
        reason: 'the controls stay on the screen turned sideways',
      );
      expect(
        tester.getSize(find.textContaining('/ 1:40')).height,
        lessThan(AppSpacing.xxxl),
        reason: 'text sized by the width must not double when it turns',
      );
      tester.setViewport(defaultViewport);
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('lesson_gv_summary'.tr()), findsOneWidget);
      await leave(tester);
    });

    testLayouts('every state fits', (tester, layout) async {
      questions.questions = [mine];
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);

      await subject.play();
      engine.report(_at(50, playing: false));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(tester.takeException(), isNull);

      engine.report(const VideoSnapshot(failed: true));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(tester.takeException(), isNull);
      await leave(tester);
    });

    testLayouts('the resume card and the sheet fit', (tester, layout) async {
      questions.questions = [mine];
      lessons.watches['les'] = const WatchState(
        videoId: 'v1',
        positionSeconds: 134,
        ranges: [(0, 34)],
      );
      await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('lesson_q_all'.tr()));
      await tester.pump();
      await tester.tap(find.text('lesson_q_all'.tr()), warnIfMissed: false);
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(tester.takeException(), isNull);
      await leave(tester);
    });
  });
}
