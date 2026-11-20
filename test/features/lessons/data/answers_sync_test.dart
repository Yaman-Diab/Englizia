import 'dart:math';

import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/answers_sync.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLessonRepository lessons;
  late FakeConnectivityService connectivity;
  late AppSessionController session;
  late AnswersSync sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    lessons = FakeLessonRepository(exercises: const []);
    connectivity = FakeConnectivityService();
    session = AppSessionController(
      tokens: FakeTokenStorage(),
      settings: SettingsStorageService(await SharedPreferences.getInstance()),
    );
    sync = AnswersSync(lessons, connectivity, session);
    addTearDown(sync.stop);
  });

  const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

  test('sends when the app opens with a session', () async {
    await session.signIn(tokens);

    sync.start();

    expect(lessons.sends, 1);
  });

  test('sends nothing with no session', () async {
    sync.start();
    connectivity
      ..online = false
      ..online = true;
    await pumpEventQueue();

    expect(lessons.sends, 0);
  });

  test('sends once a session starts', () async {
    sync.start();

    await session.signIn(tokens);

    expect(lessons.sends, 1);
  });

  test('sends when the connection returns, not when it drops', () async {
    await session.signIn(tokens);
    sync.start();
    lessons.sends = 0;

    connectivity.online = false;
    await pumpEventQueue();
    expect(lessons.sends, 0);

    connectivity.online = true;
    await pumpEventQueue();
    expect(lessons.sends, 1);
  });

  group('by itself', () {
    /// In a clock the test moves, with the sync stopped before it ends: its
    /// timers must not outlive the test.
    void timed(String description, Future<void> Function(WidgetTester) body) =>
        testWidgets(description, (tester) async {
          await body(tester);
          sync.stop();
        });

    /// Starts with a session, in the test's own time.
    Future<void> started(WidgetTester tester) async {
      await tester.runAsync(() => session.signIn(tokens));
      sync = AnswersSync(lessons, connectivity, session, random: Random(1));
      addTearDown(sync.stop);
      sync.start();
      await tester.pump();
    }

    timed('a send that failed is tried again, later each time', (tester) async {
      lessons.outcome = const SendOutcome.waiting();
      await started(tester);
      expect(lessons.sends, 1);

      // 2, 4, then 8 seconds at most, and half of each at least.
      await tester.pump(const Duration(milliseconds: 900));
      expect(lessons.sends, 1);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(lessons.sends, 2);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(lessons.sends, 2);
      await tester.pump(const Duration(milliseconds: 2100));
      expect(lessons.sends, 3);

      lessons.outcome = const SendOutcome.sent();
      await tester.pump(const Duration(seconds: 8));
      expect(lessons.sends, 4);
      await tester.pump(const Duration(seconds: 60));
      expect(lessons.sends, 4, reason: 'sent: nothing left to try');
    });

    timed('the wait never passes five minutes', (tester) async {
      lessons.outcome = const SendOutcome.waiting();
      await started(tester);
      // Far past the doubling.
      await tester.pump(const Duration(hours: 1));
      await tester.pump(const Duration(hours: 1));
      final before = lessons.sends;

      await tester.pump(AnswersSync.longestWait);

      expect(lessons.sends, greaterThan(before));
    });

    timed('the server’s own wait is the one kept', (tester) async {
      lessons.outcome = const SendOutcome.waiting(
        retryAfter: Duration(seconds: 40),
      );
      await started(tester);

      await tester.pump(const Duration(seconds: 39));
      expect(lessons.sends, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(lessons.sends, 2);
    });

    timed('it sends every few minutes while the app is in use', (tester) async {
      await started(tester);
      expect(lessons.sends, 1);

      await tester.pump(AnswersSync.every);
      expect(lessons.sends, 2);
      await tester.pump(AnswersSync.every);
      expect(lessons.sends, 3);
    });

    timed('the connection back sends at once, not at the wait’s end', (
      tester,
    ) async {
      lessons.outcome = const SendOutcome.waiting(
        retryAfter: Duration(minutes: 2),
      );
      await started(tester);

      connectivity
        ..online = false
        ..online = true;
      await tester.pump();

      expect(lessons.sends, 2);
    });
  });

  test('stopped, it sends no more', () async {
    await session.signIn(tokens);
    sync
      ..start()
      ..stop();
    lessons.sends = 0;

    connectivity
      ..online = false
      ..online = true;
    await pumpEventQueue();

    expect(lessons.sends, 0);
  });
}
