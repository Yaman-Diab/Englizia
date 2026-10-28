import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/account/presentation/account/cubit/account_cubit.dart';
import 'package:englizia/features/account/presentation/account/widgets/account_card.dart';
import 'package:englizia/features/account/presentation/sign_up/cubit/sign_up_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_accounts.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  late AppSessionController session;
  late FakeAccountRepository accounts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app.has_launched': true});
    session = AppSessionController(
      tokens: FakeTokenStorage(),
      settings: SettingsStorageService(await SharedPreferences.getInstance()),
    );
    await session.bootstrap();
    accounts = FakeAccountRepository();
  });

  group('AccountCubit', () {
    test('follows the session and signs out, telling the server', () async {
      await session.signIn(guestTokens);
      final cubit = AccountCubit(session, accounts);
      addTearDown(cubit.close);
      expect(cubit.state.isGuest, isTrue);

      await cubit.signOut();
      expect(accounts.logOuts, 1);
      expect(session.status, SessionStatus.signedOut);
      expect(cubit.state.status, SessionStatus.signedOut);
    });

    test('signing out never waits on the server', () async {
      await session.signIn(memberTokens);
      accounts.gate = Completer<void>();
      final cubit = AccountCubit(session, accounts);
      addTearDown(cubit.close);

      final signingOut = cubit.signOut();
      expect(cubit.state.signingOut, isTrue);
      accounts.gate!.complete();
      await signingOut;
      expect(session.status, SessionStatus.signedOut);
    });
  });

  group('SignUpCubit', () {
    test('a guest signing up upgrades the guest account', () async {
      final cubit = SignUpCubit(accounts, upgradesGuest: true);
      addTearDown(cubit.close);
      cubit
        ..changed(SignUpField.name, 'Learner')
        ..changed(SignUpField.email, 'user@example.com')
        ..changed(SignUpField.password, 'password1');

      await cubit.submit();
      expect(accounts.upgrades.single.email, 'user@example.com');
      expect(accounts.accounts, isEmpty);
      expect(cubit.state.session, memberTokens);
    });
  });

  group('AccountCard', () {
    Future<int> pumpCard(WidgetTester tester, {LayoutCase? layout}) async {
      var creates = 0;
      final cubit = AccountCubit(session, accounts);
      addTearDown(cubit.close);
      await tester.pumpLocalized(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: BlocProvider.value(
              value: cubit,
              child: AccountCard(onCreateAccount: () => creates++),
            ),
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      return creates;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.slow * 2);
    }

    testLayouts('lays out without overflow', (tester, layout) async {
      await session.signIn(guestTokens);
      await pumpCard(tester, layout: layout);
      await tester.tap(find.text('account_sign_out'.tr()));
      await settle(tester);
      expect(find.byType(ActionSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a guest is told the progress lives on this phone', (
      tester,
    ) async {
      await session.signIn(guestTokens);
      await pumpCard(tester);
      expect(find.text('account_guest_title'.tr()), findsOneWidget);
      expect(find.text('account_guest_create'.tr()), findsOneWidget);
    });

    testWidgets('a member sees only sign-out, which needs no warning', (
      tester,
    ) async {
      await session.signIn(memberTokens);
      await pumpCard(tester);
      expect(find.text('account_guest_title'.tr()), findsNothing);

      await tester.tap(find.text('account_sign_out'.tr()));
      await settle(tester);
      expect(find.byType(ActionSheet), findsNothing);
      expect(session.status, SessionStatus.signedOut);
    });

    testWidgets('a guest signing out is warned first', (tester) async {
      await session.signIn(guestTokens);
      await pumpCard(tester);

      await tester.tap(find.text('account_sign_out'.tr()));
      await settle(tester);
      expect(find.text('ستفقد تقدّمك لأنه غير محفوظ في حساب'), findsOneWidget);
      expect(session.status, SessionStatus.guest);

      // Dismissing keeps everything.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(session.status, SessionStatus.guest);
      expect(accounts.logOuts, 0);

      await tester.tap(find.text('account_sign_out'.tr()));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(ActionSheet),
          matching: find.text('account_sign_out'.tr()),
        ),
      );
      await settle(tester);
      expect(accounts.logOuts, 1);
      expect(session.status, SessionStatus.signedOut);
    });

    testWidgets('the warning offers the account instead', (tester) async {
      await session.signIn(guestTokens);
      var creates = 0;
      final cubit = AccountCubit(session, accounts);
      addTearDown(cubit.close);
      await tester.pumpLocalized(
        Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: AccountCard(onCreateAccount: () => creates++),
          ),
        ),
      );

      await tester.tap(find.text('account_sign_out'.tr()));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(ActionSheet),
          matching: find.text('account_guest_create'.tr()),
        ),
      );
      await settle(tester);
      expect(creates, 1);
      expect(session.status, SessionStatus.guest);
    });
  });
}
