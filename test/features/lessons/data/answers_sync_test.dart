import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/answers_sync.dart';
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
