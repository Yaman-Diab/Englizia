import 'package:dio/dio.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/router/notification_routes.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/notifications/push_channel.dart';
import 'package:englizia/core/notifications/push_message.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/notifications/data/datasources/push_token_remote_data_source.dart';
import 'package:englizia/features/notifications/data/repositories/push_token_repository_impl.dart';
import 'package:englizia/features/notifications/data/services/push_token_sync.dart';
import 'package:englizia/features/notifications/domain/repositories/push_token_repository.dart';
import 'package:englizia/features/notifications/presentation/banner/cubit/in_app_notifications_cubit.dart';
import 'package:englizia/features/notifications/presentation/off_card/cubit/notifications_card_cubit.dart';
import 'package:englizia/features/notifications/presentation/prompt/cubit/notification_prompt_cubit.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/fakes.dart';

class _Tokens implements PushTokenRepository {
  _Tokens({this.fail = false});

  final bool fail;
  final sent = <String>[];

  @override
  Future<Result<void>> register(String token) async {
    sent.add(token);
    return fail ? const Err(NetworkFailure()) : const Ok(null);
  }
}

class _Channel implements PushChannel {
  _Channel(this._token);

  final String? _token;

  @override
  Future<void> start() async {}

  @override
  Stream<PushMessage> get arrived => const Stream.empty();

  @override
  Stream<PushMessage> get opened => const Stream.empty();

  @override
  Future<PushMessage?> launchedBy() async => null;

  @override
  Future<String?> token() async => _token;

  @override
  Stream<String> get tokenChanges => const Stream.empty();
}

void main() {
  late SettingsStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = SettingsStorageService(await SharedPreferences.getInstance());
  });

  group('PushMessage', () {
    test('reads its kind, ids and the notification\'s own words', () {
      expect(
        PushMessage.fromData(
          {'type': 'teacher_reply', 'questionId': 'q1', 'lessonId': 'l1'},
          title: 'Title',
          body: ' ',
        ),
        const PushMessage(
          kind: PushKind.teacherReply,
          title: 'Title',
          questionId: 'q1',
          lessonId: 'l1',
        ),
      );
      expect(
        PushMessage.fromData({'type': 'daily_goal'})?.kind,
        PushKind.dailyGoal,
      );
      expect(PushMessage.fromData({'type': 'streak'})?.kind, PushKind.streak);
    });

    test('a kind this app doesn\'t know is left alone', () {
      expect(PushMessage.fromData({'type': 'report_fixed'}), isNull);
      expect(PushMessage.fromData({}), isNull);
    });
  });

  group('InAppNotificationsCubit', () {
    const reply = PushMessage(kind: PushKind.teacherReply, lessonId: 'l1');
    const goal = PushMessage(kind: PushKind.dailyGoal);
    const streak = PushMessage(kind: PushKind.streak);
    late DateTime now;

    InAppNotificationsCubit cubit() {
      final cubit = InAppNotificationsCubit(storage, now: () => now);
      addTearDown(cubit.close);
      return cubit;
    }

    setUp(() => now = DateTime(2026, 11, 12, 18));

    test('one banner at a time: a newer one takes its place', () async {
      final notifications = cubit();
      await notifications.arrived(reply, learning: false);
      expect(notifications.state.showing, reply);
      final first = notifications.state.serial;

      await notifications.arrived(reply, learning: false);
      expect(notifications.state.serial, first + 1);

      // The first one's leaving doesn't take the newer away.
      notifications.dismissed(first);
      expect(notifications.state.showing, reply);
      notifications.dismissed(first + 1);
      expect(notifications.state.showing, isNull);
    });

    test(
      'while learning: a reply leaves a dot, reminders are dropped',
      () async {
        final notifications = cubit();
        await notifications.arrived(goal, learning: true);
        await notifications.arrived(streak, learning: true);
        expect(notifications.state.showing, isNull);
        expect(notifications.state.meDot, isFalse);

        await notifications.arrived(reply, learning: true);
        expect(notifications.state.showing, isNull);
        expect(notifications.state.meDot, isTrue);
        // Kept for the next open.
        expect(storage.meDot, isTrue);
        expect(cubit().state.meDot, isTrue);

        await notifications.seenMe();
        expect(notifications.state.meDot, isFalse);
        expect(storage.meDot, isFalse);
      },
    );

    test('«لاحقًا» on the goal: no goal banner again today', () async {
      final notifications = cubit();
      await notifications.later();
      await notifications.arrived(goal, learning: false);
      expect(notifications.state.showing, isNull);
      await notifications.arrived(streak, learning: false);
      expect(notifications.state.showing, streak);

      now = DateTime(2026, 11, 13, 9);
      await notifications.arrived(goal, learning: false);
      expect(notifications.state.showing, goal);
    });
  });

  group('where a tap leads', () {
    test('a reply opens its lesson\'s questions; without one, home', () {
      final to = notificationDestination(
        const PushMessage(kind: PushKind.teacherReply, lessonId: 'l1'),
      );
      expect(to.location, AppRoutes.grammarOf('l1'));
      expect(to.extra, isA<OpenQuestions>());
      expect(to.push, isTrue);

      final none = notificationDestination(
        const PushMessage(kind: PushKind.teacherReply),
      );
      expect((none.location, none.extra), (AppRoutes.home, null));
    });

    test('the goal and the streak open the next lesson from home', () {
      for (final kind in [PushKind.dailyGoal, PushKind.streak]) {
        final to = notificationDestination(PushMessage(kind: kind));
        expect(to.location, AppRoutes.home);
        expect(to.extra, isA<OpenNextLesson>());
        expect(to.push, isFalse);
      }
    });

    test('learning is a lesson, a test, the microphone or onboarding', () {
      for (final path in [
        '/lessons/l1/exercises',
        '/lessons/l1/grammar',
        '/onboarding/level',
        '/onboarding/placement-test/questions',
        '/talk/scenarios/s1',
        AppRoutes.practiceReview,
        AppRoutes.practiceConceptSession,
        AppRoutes.kidsReview,
        AppRoutes.notificationPrompt,
      ]) {
        expect(isLearningPath(path), isTrue, reason: path);
      }
      for (final path in [
        AppRoutes.home,
        AppRoutes.practice,
        AppRoutes.me,
        AppRoutes.talk,
        '/units/u1',
      ]) {
        expect(isLearningPath(path), isFalse, reason: path);
      }
    });
  });

  group('the token', () {
    test('PUT /api/v1/app/me/push-token with this phone', () async {
      final adapter = FakeHttpAdapter((_) => const FakeResponse(204));
      final repository = PushTokenRepositoryImpl(
        PushTokenRemoteDataSourceImpl(
          ApiClient(
            Dio(BaseOptions(baseUrl: 'https://api.test'))
              ..httpClientAdapter = adapter,
          ),
        ),
        devicePlatform: 'android',
        deviceId: () => 'device-1',
      );

      expect(await repository.register('t1'), isA<Ok<void>>());
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/app/me/push-token');
      expect(request.data, {
        'token': 't1',
        'platform': 'android',
        'deviceId': 'device-1',
      });
    });

    Future<(PushTokenSync, _Tokens, AppSessionController)> build({
      AuthTokens? session,
      NotificationAccess access = NotificationAccess.granted,
      String? token = 't1',
      bool fail = false,
    }) async {
      final controller = AppSessionController(
        tokens: FakeTokenStorage(session),
        settings: storage,
      );
      await storage.markLaunched();
      await controller.bootstrap();
      final tokens = _Tokens(fail: fail);
      final channel = _Channel(token);
      final sync = PushTokenSync(
        channel,
        tokens,
        controller,
        FakeNotificationPermission(access: access),
        storage,
      );
      addTearDown(sync.dispose);
      return (sync, tokens, controller);
    }

    const member = AuthTokens(accessToken: 'a', refreshToken: 'r');

    test('sent once an account and the permission are there, once', () async {
      final (sync, tokens, _) = await build(session: member);
      await sync.sync();
      await sync.sync();
      expect(tokens.sent, ['t1']);
      expect(storage.pushTokenSent, 't1');
    });

    test('nothing without an account or the permission', () async {
      final (signedOut, tokens, _) = await build();
      await signedOut.sync();
      expect(tokens.sent, isEmpty);

      final (denied, tokens2, _) = await build(
        session: member,
        access: NotificationAccess.denied,
      );
      await denied.sync();
      expect(tokens2.sent, isEmpty);
    });

    test('a failed send is tried again next time', () async {
      final (sync, tokens, _) = await build(session: member, fail: true);
      await sync.sync();
      await sync.sync();
      expect(tokens.sent, ['t1', 't1']);
      expect(storage.pushTokenSent, isNull);
    });

    test(
      'another account is told again: sign-in clears what was sent',
      () async {
        final (sync, tokens, session) = await build(session: member);
        await sync.sync();
        await session.signIn(member);
        await sync.sync();
        expect(tokens.sent, ['t1', 't1']);
      },
    );
  });

  group('NotificationPromptCubit', () {
    late FakeProfileRepository profiles;
    late FakeNotificationPermission permission;

    NotificationPromptCubit cubit({
      List<Result<EffectiveSettings>> settings = const [Ok(testSettings)],
    }) {
      final controller = AppSessionController(
        tokens: FakeTokenStorage(),
        settings: storage,
      );
      final cubit = NotificationPromptCubit(
        FakeSettingsRepository(settings),
        profiles,
        permission,
        storage,
        PushTokenSync(
          MockPushChannel(),
          _Tokens(),
          controller,
          permission,
          storage,
        ),
        FakeSoundPlayer(),
      );
      addTearDown(cubit.close);
      return cubit;
    }

    setUp(() {
      profiles = FakeProfileRepository(mockProfile());
      permission = FakeNotificationPermission();
    });

    test('shown once: starting marks it', () async {
      expect(storage.notificationPromptShown, isFalse);
      await cubit().start();
      expect(storage.notificationPromptShown, isTrue);
    });

    test(
      'the panel\'s morning and evening; the onboarding time chosen',
      () async {
        final prompt = cubit();
        await prompt.start();
        expect(prompt.state.morning, const ReminderTime(8, 0));
        expect(prompt.state.evening, const ReminderTime(20, 0));
        // The fake's reminder is 20:00, the evening.
        expect(prompt.state.choice, PromptChoice.evening);

        profiles.preferences = const Preferences(
          dailyGoalMinutes: 10,
          notifications: false,
          reminderHour: 21,
          reminderMinute: 30,
        );
        final other = cubit();
        await other.start();
        expect(other.state.choice, PromptChoice.other);
        expect(other.state.custom, const ReminderTime(21, 30));
      },
    );

    test('«فعّل التذكيرات» saves the time on, then asks the phone', () async {
      final prompt = cubit();
      await prompt.start();
      prompt.choose(PromptChoice.morning);

      expect(await prompt.enable(), isTrue);
      expect(profiles.saved.last.notifications, isTrue);
      expect(
        (profiles.saved.last.reminderHour, profiles.saved.last.reminderMinute),
        (8, 0),
      );
      expect(permission.prompts, 1);
      expect(prompt.state.finished, isTrue);
    });

    test('a refusal still closes; the time stays saved', () async {
      permission.answer = NotificationAccess.denied;
      final prompt = cubit();
      await prompt.start();
      expect(await prompt.enable(), isFalse);
      expect(prompt.state.finished, isTrue);
      expect(profiles.saved, isNotEmpty);
    });

    test('«ليس الآن» counts, and closes', () async {
      final prompt = cubit();
      await prompt.start();
      await prompt.skip();
      expect(storage.notificationPromptSkips, 1);
      expect(prompt.state.finished, isTrue);
      // Once only.
      await prompt.skip();
      expect(storage.notificationPromptSkips, 1);
    });

    test('a time of the learner\'s own is chosen with it', () async {
      final prompt = cubit();
      await prompt.start();
      prompt.setCustom(const ReminderTime(6, 45));
      expect(prompt.state.choice, PromptChoice.other);
      expect(prompt.state.time, const ReminderTime(6, 45));
    });
  });

  group('NotificationsCardCubit', () {
    late FakeProfileRepository profiles;
    late FakeNotificationPermission permission;

    NotificationsCardCubit cubit() {
      final cubit = NotificationsCardCubit(profiles, permission, storage);
      addTearDown(cubit.close);
      return cubit;
    }

    setUp(() {
      profiles = FakeProfileRepository(mockProfile());
      permission = FakeNotificationPermission();
    });

    test('wanted and allowed: nothing to say', () async {
      permission.access = NotificationAccess.granted;
      final card = cubit();
      await card.check();
      expect(card.state, NotificationsCard.none);
    });

    test('wanted, but the phone keeps them off: its settings', () async {
      final card = cubit();
      await card.check();
      expect(card.state, NotificationsCard.system);
      await card.openPhoneSettings();
      expect(permission.settingsOpened, 1);
    });

    test('put off twice: «التذكيرات متوقفة»; once isn\'t enough', () async {
      profiles.preferences = const Preferences(
        dailyGoalMinutes: 10,
        notifications: false,
      );
      await storage.setNotificationPromptSkips(1);
      final card = cubit();
      await card.check();
      expect(card.state, NotificationsCard.none);

      await storage.setNotificationPromptSkips(2);
      await card.check();
      expect(card.state, NotificationsCard.off);
    });
  });
}
