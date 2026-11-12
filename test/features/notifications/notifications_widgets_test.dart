import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/shell/tab_shell.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/streak_flame.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/notifications/push_channel.dart';
import 'package:englizia/core/notifications/push_message.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/notifications/data/services/push_token_sync.dart';
import 'package:englizia/features/notifications/domain/repositories/push_token_repository.dart';
import 'package:englizia/features/notifications/presentation/banner/cubit/in_app_notifications_cubit.dart';
import 'package:englizia/features/notifications/presentation/banner/widgets/notification_banner_host.dart';
import 'package:englizia/features/notifications/presentation/off_card/cubit/notifications_card_cubit.dart';
import 'package:englizia/features/notifications/presentation/off_card/widgets/reminders_card.dart';
import 'package:englizia/features/notifications/presentation/prompt/cubit/notification_prompt_cubit.dart';
import 'package:englizia/features/notifications/presentation/prompt/pages/notification_prompt_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

class _Tokens implements PushTokenRepository {
  @override
  Future<Result<void>> register(String token) async => const Ok(null);
}

const _reply = PushMessage(kind: PushKind.teacherReply, lessonId: 'l1');
const _goal = PushMessage(kind: PushKind.dailyGoal);
const _streak = PushMessage(kind: PushKind.streak);

void main() {
  setUpAll(initLocalizationForTests);

  late SettingsStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = SettingsStorageService(await SharedPreferences.getInstance());
  });

  group('the banner', () {
    late InAppNotificationsCubit notifications;
    late List<PushMessage> opened;

    Future<void> pumpHost(
      WidgetTester tester, {
      LayoutCase? layout,
      bool screenReader = false,
      bool reduceMotion = false,
    }) async {
      notifications = InAppNotificationsCubit(storage);
      addTearDown(notifications.close);
      opened = [];
      await tester.pumpLocalized(
        BlocProvider.value(
          value: notifications,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                accessibleNavigation: screenReader,
                disableAnimations: reduceMotion,
              ),
              child: NotificationBannerHost(
                onOpen: opened.add,
                child: const Scaffold(body: SizedBox.expand()),
              ),
            ),
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
    }

    /// An animation ends on the frame after its last one.
    Future<void> gone(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.bannerOut);
      await tester.pump(AppMotion.micro);
    }

    Future<void> arrive(WidgetTester tester, PushMessage message) async {
      await notifications.arrived(message, learning: false);
      await tester.pump();
      await tester.pump(AppMotion.bannerIn);
    }

    testLayouts('fits, each kind', (tester, layout) async {
      await pumpHost(tester, layout: layout);
      for (final message in [_reply, _goal, _streak]) {
        await arrive(tester, message);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the app\'s own words for its kind; the server\'s first', (
      tester,
    ) async {
      await pumpHost(tester);
      await arrive(tester, _reply);
      expect(find.text('notification_teacher_title'.tr()), findsOneWidget);
      expect(find.text('notification_teacher_body'.tr()), findsOneWidget);

      await arrive(
        tester,
        const PushMessage(
          kind: PushKind.streak,
          title: 'سلسلتك 6 أيام بانتظارك',
          body: 'دقيقتان تكفيان.',
        ),
      );
      expect(find.text('سلسلتك 6 أيام بانتظارك'), findsOneWidget);
      expect(find.byType(StreakFlame), findsOneWidget);
    });

    testWidgets('stays four seconds, then rises away', (tester) async {
      await pumpHost(tester);
      await arrive(tester, _reply);
      await tester.pump(AppMotion.bannerHold - AppMotion.bannerIn);
      expect(find.text('notification_teacher_title'.tr()), findsOneWidget);

      await tester.pump(AppMotion.bannerIn);
      await gone(tester);
      expect(notifications.state.showing, isNull);
      await tester.pump();
      expect(find.text('notification_teacher_title'.tr()), findsNothing);
    });

    testWidgets('a newer one replaces it and counts four seconds again', (
      tester,
    ) async {
      await pumpHost(tester);
      await arrive(tester, _reply);
      await tester.pump(const Duration(seconds: 3));
      await arrive(tester, _streak);
      expect(find.text('notification_teacher_title'.tr()), findsNothing);
      expect(find.text('notification_streak_title'.tr()), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('notification_streak_title'.tr()), findsOneWidget);
    });

    testWidgets('a tap opens what it is about and closes it', (tester) async {
      await pumpHost(tester);
      await arrive(tester, _reply);
      await tester.tap(find.text('notification_teacher_body'.tr()));
      await tester.pump();
      expect(opened, [_reply]);
      await gone(tester);
      expect(notifications.state.showing, isNull);
    });

    testWidgets('the close button closes it, opening nothing', (tester) async {
      await pumpHost(tester);
      await arrive(tester, _reply);
      await tester.tap(find.bySemanticsLabel('notification_close'.tr()));
      await gone(tester);
      expect(opened, isEmpty);
      expect(notifications.state.showing, isNull);
    });

    testWidgets('dragged up past 24 it goes; less springs back', (
      tester,
    ) async {
      await pumpHost(tester);
      await arrive(tester, _reply);
      final card = find.text('notification_teacher_title'.tr());

      await tester.drag(card, const Offset(0, -12));
      await gone(tester);
      expect(notifications.state.showing, isNotNull);

      await tester.drag(card, const Offset(0, -40));
      await gone(tester);
      expect(notifications.state.showing, isNull);
      expect(opened, isEmpty);
    });

    testWidgets('the goal: «تابع الدرس» opens it, «لاحقًا» puts it off', (
      tester,
    ) async {
      await pumpHost(tester);
      await arrive(tester, _goal);
      await tester.tap(find.text('notification_goal_go'.tr()));
      await tester.pump();
      expect(opened, [_goal]);
      await gone(tester);

      await arrive(tester, _goal);
      await tester.tap(find.text('notification_goal_later'.tr()));
      await gone(tester);
      expect(opened, [_goal]);
      expect(storage.goalBannerOffDay, isNotNull);
    });

    testWidgets('under a screen reader it waits for its close button', (
      tester,
    ) async {
      await pumpHost(tester, screenReader: true);
      await arrive(tester, _reply);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('notification_teacher_title'.tr()), findsOneWidget);
    });

    testWidgets('under reduce motion it fades, still for four seconds', (
      tester,
    ) async {
      await pumpHost(tester, reduceMotion: true);
      await notifications.arrived(_reply, learning: false);
      await tester.pump();
      await tester.pump(AppMotion.bannerFade);
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('notification_teacher_title'.tr()),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
      await tester.pump(AppMotion.bannerHold);
      await tester.pump(AppMotion.bannerFade);
      await tester.pump(AppMotion.micro);
      expect(notifications.state.showing, isNull);
    });
  });

  group('the tabs\' bar', () {
    testWidgets('«أنا» carries a dot while a reply waits', (tester) async {
      final notifications = InAppNotificationsCubit(storage);
      addTearDown(notifications.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: notifications,
          child: TabShell(
            current: AppTab.learn,
            onSelect: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      final label = 'tab_with_dot'.tr(namedArgs: {'tab': 'tab_me'.tr()});
      expect(find.bySemanticsLabel(label), findsNothing);

      await notifications.arrived(_reply, learning: true);
      await tester.pump();
      expect(find.bySemanticsLabel(label), findsOneWidget);

      await notifications.seenMe();
      await tester.pump();
      expect(find.bySemanticsLabel(label), findsNothing);
    });
  });

  group('the prompt', () {
    late FakeProfileRepository profiles;
    late FakeNotificationPermission permission;
    late int done;

    Future<NotificationPromptCubit> pumpPrompt(
      WidgetTester tester, {
      bool kids = false,
      LayoutCase? layout,
    }) async {
      profiles = FakeProfileRepository(mockProfile());
      permission = FakeNotificationPermission();
      done = 0;
      final cubit = NotificationPromptCubit(
        FakeSettingsRepository(),
        profiles,
        permission,
        storage,
        PushTokenSync(
          MockPushChannel(),
          _Tokens(),
          AppSessionController(tokens: FakeTokenStorage(), settings: storage),
          permission,
          storage,
        ),
        FakeSoundPlayer(),
      );
      addTearDown(cubit.close);
      unawaited(cubit.start());
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: NotificationPromptPage(kids: kids, onDone: () => done++),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.pump(const Duration(seconds: 1));
      return cubit;
    }

    testLayouts('fits, and a child\'s too', (tester, layout) async {
      await pumpPrompt(tester, layout: layout);
      expect(find.text('notification_prompt_title'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpPrompt(tester, layout: layout, kids: true);
      expect(find.text('notification_prompt_title_kids'.tr()), findsOneWidget);
      expect(find.text('notification_prompt_later_note'.tr()), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the panel\'s morning and evening, the evening chosen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPrompt(tester);
      // The panel's 8:00 and 20:00 both read 8:00 under their label.
      expect(find.text('8:00'), findsNWidgets(2));
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            RegExp('^${'notification_prompt_evening'.tr()}'),
          ),
        ),
        isSemantics(
          isChecked: true,
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          isButton: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('«فعّل التذكيرات» saves the time, asks the phone, closes', (
      tester,
    ) async {
      await pumpPrompt(tester);
      await tester.tap(find.text('notification_prompt_morning'.tr()));
      await tester.pump();
      await tester.tap(find.text('notification_prompt_enable'.tr()));
      await tester.pump();
      await tester.pump();
      expect(permission.prompts, 1);
      expect(profiles.saved.last.reminderHour, 8);
      expect(profiles.saved.last.notifications, isTrue);
      expect(done, 1);
    });

    testWidgets('«ليس الآن», top or bottom, counts once and closes', (
      tester,
    ) async {
      await pumpPrompt(tester);
      await tester.tap(find.text('notification_prompt_skip'.tr()).first);
      await tester.pump();
      expect(done, 1);
      expect(storage.notificationPromptSkips, 1);
      expect(permission.prompts, 0);
    });

    testWidgets('back is «ليس الآن»', (tester) async {
      await pumpPrompt(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(storage.notificationPromptSkips, 1);
      expect(done, 1);
    });

    testWidgets('«وقت آخر» opens the wheels; saving chooses it', (
      tester,
    ) async {
      final cubit = await pumpPrompt(tester);
      await tester.tap(find.text('notification_prompt_other'.tr()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('onboarding_reminder_sheet_title'.tr()), findsOneWidget);
      await tester.tap(find.text('common_save'.tr()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(cubit.state.choice, PromptChoice.other);
      expect(cubit.state.custom, isNotNull);
    });
  });

  group('«أنا»\'s card', () {
    Future<NotificationsCardCubit> pumpCard(
      WidgetTester tester, {
      required bool wanted,
      NotificationAccess access = NotificationAccess.denied,
      int skips = 0,
      Future<void> Function()? onEnable,
    }) async {
      final profiles = FakeProfileRepository(
        mockProfile(),
      )..preferences = Preferences(dailyGoalMinutes: 10, notifications: wanted);
      await storage.setNotificationPromptSkips(skips);
      final cubit = NotificationsCardCubit(
        profiles,
        FakeNotificationPermission(access: access),
        storage,
      );
      addTearDown(cubit.close);
      unawaited(cubit.check());
      await tester.pumpLocalized(
        Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: RemindersCard(onEnable: onEnable ?? () async {}),
          ),
        ),
      );
      await tester.pump(AppMotion.slow);
      return cubit;
    }

    testWidgets('put off twice: «التذكيرات متوقفة» and «فعّلها»', (
      tester,
    ) async {
      var prompts = 0;
      await pumpCard(
        tester,
        wanted: false,
        skips: 2,
        onEnable: () async => prompts++,
      );
      expect(find.text('notification_card_off'.tr()), findsOneWidget);
      await tester.tap(find.text('notification_card_enable'.tr()));
      await tester.pump();
      expect(prompts, 1);
    });

    testWidgets('kept off by the phone: its settings', (tester) async {
      await pumpCard(tester, wanted: true);
      expect(find.text('settings_notifications_off'.tr()), findsOneWidget);
      expect(find.text('settings_open_phone'.tr()), findsOneWidget);
    });

    testWidgets('on: nothing', (tester) async {
      await pumpCard(
        tester,
        wanted: true,
        access: NotificationAccess.granted,
        skips: 3,
      );
      expect(find.text('notification_card_off'.tr()), findsNothing);
      expect(find.text('settings_notifications_off'.tr()), findsNothing);
    });
  });
}
