import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/data/datasources/unit_test_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/unit_test_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/unit_test.dart';
import 'package:englizia/features/lessons/domain/repositories/unit_test_repository.dart';
import 'package:englizia/features/lessons/presentation/unit_test/cubit/unit_test_cubit.dart';
import 'package:englizia/features/lessons/presentation/unit_test/pages/unit_test_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

/// The mock's test, read as the server sends it (its key left out).
UnitTest _unitTest({
  UnitTestState state = UnitTestState.available,
  DateTime? retryAt,
}) {
  final json = asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(UnitTestFakeDataSource.asset).readAsStringSync()),
    ),
  )..remove('mockLevels');
  for (final question in json.readList('questions')!) {
    asJsonMap(question).remove('mockKey');
  }
  json
    ..['state'] = state.name
    ..['retryAvailableAt'] = retryAt?.toUtc().toIso8601String();
  return UnitTestModel(json).toEntity('seed');
}

const _passed = UnitTestResult(
  correct: 5,
  questionCount: 5,
  percent: 100,
  passed: true,
  passPercent: 70,
  bestPercent: 100,
  marks: [true, true, true, true, true],
  suggestion: LevelSuggestion(
    id: 'lc',
    up: true,
    percent: 100,
    level: LevelName(id: 'a2', label: 'A2', name: 'ما قبل المتوسط'),
    suggested: LevelName(id: 'b1', label: 'B1', name: 'المتوسط'),
  ),
);

class _Tests implements UnitTestRepository {
  UnitTest test = _unitTest();
  final results = <Result<UnitTestResult>>[];
  final sent = <(Map<String, ExerciseDraft>, String)>[];
  final choices = <bool>[];
  var reads = 0;

  @override
  Future<Result<UnitTest>> getTest(String testId) async {
    reads++;
    return Ok(test);
  }

  @override
  Future<Result<UnitTestResult>> submit(
    UnitTest test,
    Map<String, ExerciseDraft> answers, {
    required String submissionId,
  }) async {
    sent.add((answers, submissionId));
    return results.isEmpty ? const Ok(_passed) : results.removeAt(0);
  }

  @override
  Future<Result<void>> chooseLevel(String id, {required bool move}) async {
    choices.add(move);
    return const Ok(null);
  }
}

/// An answer for each of the mock's five questions, in turn.
ExerciseDraft _answerTo(Exercise question) => switch (question) {
  ChoiceExercise(:final options) => ChoiceDraft(options.first.id),
  FillChoicesExercise(:final bank) => SlotsDraft([bank.first]),
  WordOrderExercise(:final bank) => SequenceDraft([bank.first], needed: 1),
  MatchingExercise(:final pairs) => LinksDraft(
    total: pairs.length,
    links: {for (final pair in pairs) pair.id: pair.id},
  ),
  _ => throw StateError('not in the mock'),
};

void main() {
  setUpAll(initLocalizationForTests);

  late _Tests tests;
  late FakeLessonRepository lessons;
  late DateTime now;

  setUp(() {
    tests = _Tests();
    lessons = FakeLessonRepository(exercises: const []);
    now = DateTime.utc(2026, 11, 24, 9);
  });

  UnitTestCubit cubit() => UnitTestCubit(
    tests,
    lessons,
    FakeClipPlayer(),
    testId: 'ut_mock',
    now: () => now,
  );

  Future<void> answerAll(UnitTestCubit subject) async {
    for (var left = subject.state.test!.questions.length; left > 0; left--) {
      subject.updateDraft(_answerTo(subject.state.question!));
      await subject.next();
    }
  }

  group('UnitTestCubit', () {
    test('the lessons’ answers go first, then the test is read', () async {
      final subject = cubit();
      addTearDown(subject.close);

      await subject.start();

      expect(lessons.sends, 1);
      expect(tests.reads, 1);
      expect(subject.state.phase, UnitTestPhase.intro);
      expect(subject.state.canStart, isTrue);
    });

    test('one question at a time, kept until the whole goes', () async {
      final subject = cubit();
      addTearDown(subject.close);
      await subject.start();
      subject.begin();

      expect(subject.state.phase, UnitTestPhase.answering);
      expect(subject.state.canGoOn, isFalse);
      await subject.next();
      expect(subject.state.index, 0, reason: 'no answer, no next');

      await answerAll(subject);

      expect(subject.state.phase, UnitTestPhase.result);
      expect(tests.sent.single.$1, hasLength(5));
      expect(subject.state.result, _passed);
    });

    test(
      'a send that failed keeps the answers, and goes again as itself',
      () async {
        tests.results.add(const Err(NetworkFailure()));
        final subject = cubit();
        addTearDown(subject.close);
        await subject.start();
        subject.begin();

        await answerAll(subject);

        expect(subject.state.phase, UnitTestPhase.answering);
        expect(subject.state.sendFailed, isTrue);
        expect(subject.state.answers, hasLength(5));

        await subject.send();

        expect(subject.state.phase, UnitTestPhase.result);
        expect(tests.sent[1].$2, tests.sent[0].$2, reason: 'one try, one id');
      },
    );

    test('a new try has a new id', () async {
      final subject = cubit();
      addTearDown(subject.close);
      await subject.start();
      subject.begin();
      await answerAll(subject);
      await subject.start();
      subject.begin();
      await answerAll(subject);

      expect(tests.sent[1].$2, isNot(tests.sent[0].$2));
    });

    test('too soon after a fail: back to the start, with the wait', () async {
      tests.results.add(
        const Err(RateLimitFailure(retryAfter: Duration(minutes: 4))),
      );
      final subject = cubit();
      addTearDown(subject.close);
      await subject.start();
      subject.begin();

      await answerAll(subject);

      expect(subject.state.phase, UnitTestPhase.intro);
      expect(subject.state.waitLeft, const Duration(minutes: 4));
      expect(subject.state.canStart, isFalse);
    });

    test('«انتقل» goes once, and the card is done', () async {
      final subject = cubit();
      addTearDown(subject.close);
      await subject.start();
      subject.begin();
      await answerAll(subject);

      expect(await subject.chooseLevel(move: true), isNull);
      expect(tests.choices, [true]);
      expect(subject.state.chosen, isTrue);
    });
  });

  group('UnitTestPage', () {
    Future<UnitTestCubit> pump(
      WidgetTester tester, {
      LayoutCase? layout,
    }) async {
      final subject = cubit();
      addTearDown(subject.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: UnitTestPage(onDone: () {}),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await subject.start();
      await tester.settleEntrance(const Duration(seconds: 1));
      return subject;
    }

    Future<void> leaveClean(WidgetTester tester, UnitTestCubit subject) async {
      await subject.stopAudio();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testLayouts('its start fits', (tester, layout) async {
      await pump(tester, layout: layout);

      expect(find.text('unit_test_title'.tr()), findsOneWidget);
      expect(find.text('unit_test_start'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wait counts down, and the test opens when it is over', (
      tester,
    ) async {
      tests.test = _unitTest(
        state: UnitTestState.cooldown,
        retryAt: now.add(const Duration(seconds: 3)),
      );
      final subject = await pump(tester);

      expect(
        find.text('unit_test_wait'.tr(namedArgs: {'time': '00:03'})),
        findsOneWidget,
      );
      final start = tester.widget<AppButton>(find.byType(AppButton));
      expect(start.onPressed, isNull);

      tests.test = _unitTest();
      now = now.add(const Duration(seconds: 3));
      await tester.pump(UnitTestCubit.tick);
      await tester.pump();

      expect(tests.reads, 2);
      expect(subject.state.canStart, isTrue);
      await leaveClean(tester, subject);
    });

    testLayouts('a question with no hint, and «التالي» once answered', (
      tester,
      layout,
    ) async {
      final subject = await pump(tester, layout: layout);
      subject.begin();
      await tester.settleEntrance(const Duration(seconds: 1));

      final next = find.widgetWithText(AppButton, 'unit_test_next'.tr());
      expect(tester.widget<AppButton>(next).onPressed, isNull);
      expect(find.text('lesson_check'.tr()), findsNothing);

      subject.updateDraft(_answerTo(subject.state.question!));
      await tester.settleEntrance(const Duration(milliseconds: 300));
      expect(tester.widget<AppButton>(next).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await leaveClean(tester, subject);
    });

    testWidgets('a matching links freely: the same number on both', (
      tester,
    ) async {
      final subject = await pump(tester);
      subject.begin();
      while (subject.state.question is! MatchingExercise) {
        subject.updateDraft(_answerTo(subject.state.question!));
        await subject.next();
      }
      await tester.settleEntrance(const Duration(seconds: 1));
      final match = subject.state.question! as MatchingExercise;

      await tester.tap(find.text(match.wordsShown.first.id));
      await tester.pump();
      await tester.tap(find.text(match.meaningsShown.last.meaning));
      await tester.pump(const Duration(milliseconds: 600));

      final draft = subject.state.draft! as LinksDraft;
      expect(draft.links, {
        match.wordsShown.first.id: match.meaningsShown.last.id,
      });
      expect(find.text('1'), findsNWidgets(2));
      await leaveClean(tester, subject);
    });

    testLayouts('the result, and the level suggested', (tester, layout) async {
      final subject = await pump(tester, layout: layout);
      subject.begin();
      await answerAll(subject);
      await tester.settleEntrance(const Duration(seconds: 1));

      expect(find.text('unit_test_passed'.tr()), findsOneWidget);
      expect(
        find.text('unit_test_percent'.tr(namedArgs: {'percent': '100'})),
        findsOneWidget,
      );
      expect(
        find.text('level_suggestion_move'.tr(namedArgs: {'level': 'B1'})),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await leaveClean(tester, subject);
    });
  });
}
