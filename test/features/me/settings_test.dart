import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:englizia/features/me/presentation/settings/cubit/preferences_cubit.dart';
import 'package:englizia/features/me/presentation/settings/pages/account_pages.dart';
import 'package:englizia/features/me/presentation/settings/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_lesson_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/fake_track_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _wrong = ValidationFailure(
  fieldCodes: {
    'currentPassword': ['wrong'],
    'password': ['wrong'],
  },
);

void main() {
  setUpAll(initLocalizationForTests);

  final today = DateTime(2026, 11, 5, 10);
  late FakeProfileRepository profiles;
  late FakeLessonRepository lessons;
  late FakeNotificationPermission permission;

  setUp(() {
    profiles = FakeProfileRepository(mockProfile(now: today));
    lessons = FakeLessonRepository();
    permission = FakeNotificationPermission(access: NotificationAccess.granted);
  });

  PreferencesCubit cubit() {
    final subject = PreferencesCubit(
      profiles,
      FakeSettingsRepository(),
      lessons,
      permission,
    );
    addTearDown(subject.close);
    return subject;
  }

  group('the cubit', () {
    test(
      'the preferences, the panel\'s goals and the phone\'s permission',
      () async {
        final subject = cubit();
        await subject.start();

        expect(subject.state.load, LoadStatus.ready);
        expect(subject.state.preferences?.dailyGoalMinutes, 10);
        expect(subject.state.goals?.options, hasLength(4));
        expect(subject.state.notificationsOn, isTrue);
        expect(subject.state.phoneBlocks, isFalse);
      },
    );

    test('a change shows at once; one refused goes back', () async {
      final subject = cubit();
      await subject.start();

      expect(await subject.setGoal(20), isNull);
      expect(profiles.saved.last.dailyGoalMinutes, 20);

      profiles.writeFailure = const NetworkFailure();
      expect(await subject.setReminder(7, 30), isA<NetworkFailure>());
      expect(subject.state.preferences?.reminderHour, 20);
    });

    test(
      'notifications: all or none, and the phone has the last word',
      () async {
        permission = FakeNotificationPermission(
          answer: NotificationAccess.denied,
        );
        profiles.preferences = const Preferences(
          dailyGoalMinutes: 10,
          notifications: false,
        );
        final subject = cubit();
        await subject.start();
        expect(subject.state.phoneBlocks, isFalse, reason: 'never asked');

        await subject.setNotifications(on: true);
        expect(permission.prompts, 1);
        expect(subject.state.phoneBlocks, isTrue);
        expect(subject.state.notificationsOn, isFalse);
        expect(profiles.saved, isEmpty);

        permission.access = NotificationAccess.granted;
        await subject.recheck();
        await subject.setNotifications(on: true);
        expect(profiles.saved.single.notifications, isTrue);
        expect(subject.state.notificationsOn, isTrue);

        await subject.setNotifications(on: false);
        expect(profiles.saved.last.notifications, isFalse);
      },
    );

    test('the video\'s quality stays on this phone', () async {
      final subject = cubit();
      await subject.start();
      await subject.setVideoQuality(VideoQuality.low);
      expect(lessons.videoQuality, VideoQuality.low);
      expect(profiles.saved, isEmpty);
    });

    test('the password and the deletion say what went wrong', () async {
      final subject = cubit();
      expect(await subject.changePassword('old', 'new password'), isNull);
      expect(profiles.passwords.single, ('old', 'new password'));

      profiles.passwordFailure = _wrong;
      expect(await subject.deleteAccount(password: 'x'), _wrong);
      expect(subject.state.saving, isFalse);
    });

    test('vibration can be turned off for the whole app', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsCubit(
        SettingsStorageService(await SharedPreferences.getInstance()),
      );
      addTearDown(settings.close);
      expect(AppHaptics.enabled, isTrue);

      await settings.setVibration(on: false);
      expect(AppHaptics.enabled, isFalse);
      expect(settings.state.vibration, isFalse);
      await settings.setVibration(on: true);
    });
  });

  group('the page', () {
    late List<String> did;

    Future<PreferencesCubit> pump(
      WidgetTester tester, {
      bool guest = false,
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      did = [];
      SharedPreferences.setMockInitialValues({});
      final storage = SettingsStorageService(
        await SharedPreferences.getInstance(),
      );
      final me = MeCubit(
        profiles,
        FakeTrackRepository(levels: [Ok(mockEmarLevels())]),
        isGuest: () => guest,
        now: () => today,
      );
      final preferences = cubit();
      final device = SettingsCubit(storage);
      addTearDown(me.close);
      addTearDown(device.close);
      await tester.pumpLocalized(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: me),
            BlocProvider.value(value: preferences),
            BlocProvider.value(value: device),
          ],
          child: SettingsPage(
            actions: SettingsActions(
              onBack: () => did.add('back'),
              onWhatsApp: (_) => did.add('whatsapp'),
              onPrivacy: () => did.add('privacy'),
              onTerms: () => did.add('terms'),
              onSignOut: () async => did.add('out'),
              onCreateAccount: () => did.add('account'),
              onVerifyEmail: () async => did.add('verify'),
              onPassword: () async {
                did.add('password');
                return true;
              },
              onDelete: () => did.add('delete'),
              version: '1.0.0',
            ),
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await me.start();
      await preferences.start();
      await settle(tester);
      return preferences;
    }

    testWidgets('one switch for notifications, no reading size', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('settings_notifications_allow'.tr()), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(3));
      expect(find.text('settings_version'.tr(args: ['1.0.0'])), findsNothing);
      await tester.scrollUntilVisible(
        find.text('settings_version'.tr(args: ['1.0.0'])),
        300,
      );
      expect(find.text('settings_terms'.tr()), findsOneWidget);
    });

    testWidgets('the goal from its sheet, saved at once', (tester) async {
      final subject = await pump(tester);

      await tester.tap(find.text('settings_goal'.tr()));
      await settle(tester);
      await tester.tap(find.text('onboarding_goal_per_day'.plural(15)));
      await settle(tester);

      expect(subject.state.preferences?.dailyGoalMinutes, 15);
      expect(find.text('settings_goal_value'.tr(args: ['15'])), findsOneWidget);
    });

    testWidgets('the phone refused: the band opens its settings', (
      tester,
    ) async {
      permission = FakeNotificationPermission();
      await pump(tester);

      expect(find.text('settings_notifications_off'.tr()), findsOneWidget);
      await tester.tap(find.text('settings_open_phone'.tr()));
      expect(permission.settingsOpened, 1);
    });

    testWidgets('a saved password is said', (tester) async {
      await pump(tester);

      await tester.tap(find.text('settings_password'.tr()));
      await settle(tester);
      expect(did, ['password']);
      expect(find.text('settings_password_saved'.tr()), findsOneWidget);
    });

    testLayouts('it fits', (tester, layout) async {
      for (final guest in [false, true]) {
        await pump(
          tester,
          guest: guest,
          locale: layout.locale,
          size: layout.size,
          themeMode: layout.themeMode,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('the account\'s pages', () {
    Future<PreferencesCubit> host(WidgetTester tester, Widget page) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(value: subject, child: page),
      );
      return subject;
    }

    testWidgets('«حفظ» waits for both passwords; a wrong one is said', (
      tester,
    ) async {
      var saved = 0;
      await host(tester, PasswordPage(onBack: () {}, onSaved: () => saved++));
      final fields = find.byType(TextField);
      final save = find.widgetWithText(FilledButton, 'common_save'.tr());

      await tester.enterText(fields.last, 'short');
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      profiles.passwordFailure = _wrong;
      await tester.enterText(fields.first, 'old');
      await tester.enterText(fields.last, 'long enough');
      await tester.pump();
      await tester.tap(save);
      await settle(tester);
      expect(find.text('settings_password_wrong'.tr()), findsOneWidget);

      profiles.passwordFailure = null;
      await tester.tap(save);
      await settle(tester);
      expect(saved, 1);
    });

    testWidgets('deleting: what goes, the password, then gone', (tester) async {
      var done = 0;
      await host(
        tester,
        DeleteAccountPage(
          signIn: SignInMethod.email,
          onBack: () {},
          onReauthenticate: () async => false,
          onDone: () => done++,
        ),
      );

      expect(find.text('settings_delete_progress'.tr()), findsOneWidget);
      await tester.tap(find.text('settings_delete_continue'.tr()));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'password');
      await tester.pump();
      await tester.tap(find.text('settings_delete_button'.tr()));
      await settle(tester);

      expect(profiles.deletions.single, 'password');
      expect(find.text('settings_delete_done'.tr()), findsOneWidget);
      await tester.tap(find.text('settings_delete_start'.tr()));
      expect(done, 1);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
