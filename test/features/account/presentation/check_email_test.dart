import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/illustrations/mail_scene.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/mail/mail_app.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/account/presentation/check_email/cubit/check_email_cubit.dart';
import 'package:englizia/features/account/presentation/check_email/pages/check_email_page.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_accounts.dart';
import '../../../helpers/pump_app.dart';

class _FakeMailApp implements MailApp {
  _FakeMailApp({this.opens = true});

  final bool opens;
  var tries = 0;

  @override
  Future<bool> open() async {
    tries++;
    return opens;
  }
}

void main() {
  setUpAll(initLocalizationForTests);

  const email = 'user@example.com';
  late DateTime clock;
  late _FakeMailApp mail;

  setUp(() {
    clock = DateTime.utc(2026, 10, 30, 12);
    mail = _FakeMailApp();
  });

  CheckEmailCubit cubitWith(FakeAccountRepository accounts) {
    final cubit = CheckEmailCubit(
      accounts,
      mail,
      email: email,
      now: () => clock,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// Ends the wait under way, so the countdown's timer stops by itself.
  Future<void> endWait(WidgetTester tester, CheckEmailCubit cubit) async {
    clock = cubit.state.resendAt;
    await tester.pump(const Duration(seconds: 1));
  }

  group('PlatformMailApp', () {
    const channel = MethodChannel('englizia/mail_app');
    final messenger =
        TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('asks the native side, which says if a mail app opened', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'open');
        return true;
      });
      expect(await const PlatformMailApp().open(), isTrue);
    });

    test('anything going wrong counts as no mail app', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'failed');
      });
      expect(await const PlatformMailApp().open(), isFalse);

      messenger.setMockMethodCallHandler(channel, null);
      expect(await const PlatformMailApp().open(), isFalse);
    });
  });

  group('CheckEmailCubit', () {
    testWidgets('resending waits, and the wait grows: 1, 2, then 5 minutes', (
      tester,
    ) async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts);
      expect(cubit.state.waitLeft, const Duration(minutes: 1));
      expect(cubit.state.canResend, isFalse);
      await cubit.resend();
      expect(accounts.resetRequests, isEmpty);

      for (final wait in const [
        Duration(minutes: 2),
        Duration(minutes: 5),
        Duration(minutes: 5),
      ]) {
        await endWait(tester, cubit);
        expect(cubit.state.canResend, isTrue);
        await cubit.resend();
        expect(cubit.state.waitLeft, wait);
      }
      expect(accounts.resetRequests, [email, email, email]);
      expect(cubit.state.resent, 3);
      await endWait(tester, cubit);
    });

    testWidgets('counts down each second', (tester) async {
      final cubit = cubitWith(FakeAccountRepository());
      clock = clock.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(cubit.state.waitLeft, const Duration(seconds: 59));
      await endWait(tester, cubit);
    });

    testWidgets('too many requests count as sent, telling nothing', (
      tester,
    ) async {
      final cubit = cubitWith(
        FakeAccountRepository(resetResults: const [Err(RateLimitFailure())]),
      );
      await endWait(tester, cubit);
      await cubit.resend();
      expect(cubit.state.resent, 1);
      expect(cubit.state.failure, isNull);
      await endWait(tester, cubit);
    });

    testWidgets('a failed connection can retry at once', (tester) async {
      final cubit = cubitWith(
        FakeAccountRepository(
          resetResults: const [Err(NetworkFailure()), Ok(null)],
        ),
      );
      await endWait(tester, cubit);
      await cubit.resend();
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.canResend, isTrue);

      await cubit.resend();
      expect(cubit.state.failure, isNull);
      expect(cubit.state.resent, 1);
      await endWait(tester, cubit);
    });

    testWidgets('a phone with no mail app is noted', (tester) async {
      mail = _FakeMailApp(opens: false);
      final cubit = cubitWith(FakeAccountRepository());
      await cubit.openMailApp();
      expect(cubit.state.noMailApp, 1);
      await endWait(tester, cubit);
    });
  });

  group('CheckEmailPage', () {
    Future<CheckEmailCubit> pumpPage(
      WidgetTester tester, {
      FakeAccountRepository? accounts,
      VoidCallback? onChange,
      LayoutCase? layout,
    }) async {
      final cubit = cubitWith(accounts ?? FakeAccountRepository());
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: CheckEmailPage(onChange: onChange ?? () {}),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.pump(const Duration(milliseconds: 900));
      return cubit;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.slow * 2);
    }

    AppButton resend(WidgetTester tester) => tester.widget<AppButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppButton && widget.variant == AppButtonVariant.secondary,
      ),
    );

    testLayouts('lays out without overflow', (tester, layout) async {
      final cubit = await pumpPage(tester, layout: layout);
      expect(find.byType(MailScene), findsOneWidget);
      expect(tester.takeException(), isNull);
      await endWait(tester, cubit);
    });

    testWidgets('says the link went out only if the account exists', (
      tester,
    ) async {
      final cubit = await pumpPage(tester);
      expect(find.text('check_email_title'.tr()), findsOneWidget);
      expect(find.text('check_email_body'.tr()), findsOneWidget);
      expect(find.text(email), findsOneWidget);
      expect(find.text('check_email_valid'.tr()), findsOneWidget);
      await endWait(tester, cubit);
    });

    testWidgets('the wait shows on the button, then it can send', (
      tester,
    ) async {
      final accounts = FakeAccountRepository();
      final cubit = await pumpPage(tester, accounts: accounts);
      expect(resend(tester).onPressed, isNull);
      expect(
        resend(tester).label,
        'أعد الإرسال بعد ${Unicode.LRI}1:00${Unicode.PDI}',
      );

      await endWait(tester, cubit);
      expect(resend(tester).label, 'check_email_resend'.tr());
      await tester.tap(find.text('check_email_resend'.tr()));
      await settle(tester);

      expect(accounts.resetRequests, [email]);
      expect(find.text('check_email_resent'.tr()), findsOneWidget);
      expect(
        resend(tester).label,
        'أعد الإرسال بعد ${Unicode.LRI}2:00${Unicode.PDI}',
      );
      await endWait(tester, cubit);
    });

    testWidgets('opens the mail app, or says there is none', (tester) async {
      mail = _FakeMailApp(opens: false);
      final cubit = await pumpPage(tester);
      await tester.tap(find.text('check_email_open'.tr()));
      await settle(tester);
      expect(mail.tries, 1);
      expect(find.text('check_email_no_mail_app'.tr()), findsOneWidget);
      await endWait(tester, cubit);
    });

    testWidgets('a failed resend says so and retries', (tester) async {
      final accounts = FakeAccountRepository(
        resetResults: const [Err(NetworkFailure()), Ok(null)],
      );
      final cubit = await pumpPage(tester, accounts: accounts);
      await endWait(tester, cubit);
      await tester.tap(find.text('check_email_resend'.tr()));
      await settle(tester);
      expect(find.text('error_network'.tr()), findsOneWidget);

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(accounts.resetRequests, hasLength(2));
      expect(cubit.state.resent, 1);
      await endWait(tester, cubit);
    });

    testWidgets('"change" goes back to the email', (tester) async {
      var changes = 0;
      final cubit = await pumpPage(tester, onChange: () => changes++);
      await tester.tap(find.text('check_email_change'.tr()));
      expect(changes, 1);
      await endWait(tester, cubit);
    });

    testWidgets('buttons and links meet the tap target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final cubit = await pumpPage(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await endWait(tester, cubit);
    });
  });
}
