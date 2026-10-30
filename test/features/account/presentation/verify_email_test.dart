import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/notice_card.dart';
import 'package:englizia/core/design_system/widgets/success_badge.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/mail/mail_app.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/domain/entities/account_email.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/email_link_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/verify_email_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/pages/email_link_page.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_banner.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_host.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_row.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_accounts.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _FakeMailApp implements MailApp {
  _FakeMailApp({this.opens = true});

  final bool opens;
  var calls = 0;

  @override
  Future<bool> open() async {
    calls++;
    return opens;
  }
}

const _unverified = AccountEmail(email: 'user@example.com', verified: false);
const _verified = AccountEmail(email: 'user@example.com', verified: true);

void main() {
  setUpAll(initLocalizationForTests);

  late SettingsStorageService settings;
  late DateTime clock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStorageService(await SharedPreferences.getInstance());
    clock = DateTime.utc(2026, 11);
  });

  VerifyEmailCubit cubitWith(
    FakeAccountRepository accounts, {
    bool member = true,
    MailApp? mail,
  }) {
    final cubit = VerifyEmailCubit(
      accounts,
      mail ?? _FakeMailApp(),
      settings,
      isMember: () => member,
      now: () => clock,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('data', () {
    late FakeHttpAdapter adapter;
    late FakeResponse Function(RequestOptions) answer;

    setUp(() {
      answer = (_) => const FakeResponse(200);
      adapter = FakeHttpAdapter((options) => answer(options));
    });

    AccountRepositoryImpl repository() => AccountRepositoryImpl(
      AccountRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      ),
      tokens: FakeTokenStorage(),
      installationId: () async => 'i',
      savedDeviceId: () => null,
      saveDeviceId: (_) async {},
      devicePlatform: null,
    );

    test('the email comes from /app/me, as the contract has it', () async {
      answer = (_) => const FakeResponse(
        200,
        body: {
          'statusCode': 200,
          'data': {'email': 'user@example.com', 'emailVerified': true},
        },
      );
      final result = await repository().getEmail();
      expect((result as Ok<AccountEmail>).value, _verified);
      expect(adapter.requests.single.path, '/api/v1/app/me');
    });

    test('a guest has no email', () async {
      answer = (_) => const FakeResponse(
        200,
        body: {
          'statusCode': 200,
          'data': {'email': null, 'emailVerified': false},
        },
      );
      final result = await repository().getEmail();
      expect((result as Ok<AccountEmail>).value.email, isNull);
    });

    test('resending and correcting use the account\'s session', () async {
      await repository().resendEmailLink();
      expect(adapter.requests.last.path, '/api/v1/auth/email/resend');

      await repository().changeEmail(' new@example.com ');
      expect(adapter.requests.last.method, 'PUT');
      expect(adapter.requests.last.path, '/api/v1/auth/email');
      expect(adapter.requests.last.data, {'email': 'new@example.com'});
    });

    test('an email with an account is a conflict', () async {
      answer = (_) => const FakeResponse(409);
      final result = await repository().changeEmail('taken@example.com');
      expect((result as Err).failure, isA<ConflictFailure>());
    });

    test('the link: POST with its token', () async {
      await repository().verifyEmail('t-1');
      expect(adapter.requests.single.path, '/api/v1/auth/email/verify');
      expect(adapter.requests.single.data, {'token': 't-1'});
    });

    test('a link out of date is its own failure', () async {
      answer = (_) => const FakeResponse(410);
      final result = await repository().verifyEmail('t-1');
      expect((result as Err).failure, isA<LinkExpiredFailure>());
    });

    test('mock mode: unconfirmed, then confirmed by the link', () async {
      final fake = AccountFakeDataSource(_DiskBundle(), latency: Duration.zero);
      expect(await fake.getEmail(), _unverified);

      await expectLater(
        fake.verifyEmail(AccountFakeDataSource.expiredResetToken),
        throwsA(isA<ApiException>()),
      );
      await fake.verifyEmail('good');
      expect((await fake.getEmail()).verified, isTrue);
    });

    test('mock mode: correcting changes it, or says why not', () async {
      final fake = AccountFakeDataSource(_DiskBundle(), latency: Duration.zero);
      await fake.resendEmailLink();
      await fake.changeEmail('new@example.com');
      expect((await fake.getEmail()).email, 'new@example.com');
      await expectLater(
        fake.changeEmail(AccountFakeDataSource.takenEmail),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        fake.changeEmail(AccountFakeDataSource.unreachableEmail),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('VerifyEmailCubit', () {
    test('a member with an unconfirmed email gets the reminder', () async {
      final cubit = cubitWith(FakeAccountRepository());
      await cubit.load();
      expect(cubit.state.email, 'user@example.com');
      expect(cubit.state.showsReminder, isTrue);
    });

    test('a guest asks nothing and sees nothing', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts, member: false);
      await cubit.load();
      expect(accounts.emailReads, 0);
      expect(cubit.state.applies, isFalse);
      expect(cubit.state.showsReminder, isFalse);
    });

    test('Google and Apple arrive confirmed: no reminder', () async {
      final cubit = cubitWith(
        FakeAccountRepository(emailResults: const [Ok(_verified)]),
      );
      await cubit.load();
      expect(cubit.state.applies, isTrue);
      expect(cubit.state.showsReminder, isFalse);
    });

    test(
      'a failed read changes nothing, and never stops the learner',
      () async {
        final cubit = cubitWith(
          FakeAccountRepository(emailResults: const [Err(NetworkFailure())]),
        );
        await cubit.load();
        expect(cubit.state.applies, isFalse);
      },
    );

    test('confirmed elsewhere: coming back folds the reminder', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          emailResults: const [Ok(_unverified), Ok(_verified)],
        ),
      );
      await cubit.load();
      expect(cubit.state.showsReminder, isTrue);
      await cubit.load();
      expect(cubit.state.verified, isTrue);
      expect(cubit.state.showsReminder, isFalse);
    });

    test('hiding lasts 3 days, then the reminder comes back', () async {
      final cubit = cubitWith(FakeAccountRepository());
      await cubit.load();
      await cubit.hideReminder();
      expect(cubit.state.showsReminder, isFalse);
      // The badge stays.
      expect(cubit.state.applies, isTrue);

      clock = clock.add(const Duration(days: 2));
      await cubit.load();
      expect(cubit.state.showsReminder, isFalse);

      final later = cubitWith(FakeAccountRepository());
      clock = clock.add(const Duration(days: 2));
      await later.load();
      expect(later.state.showsReminder, isTrue);
    });

    test('resending: no wait at first, and longer each time', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts);
      await cubit.load();
      expect(cubit.state.canResend, isTrue);

      await cubit.resend();
      expect(accounts.linkResends, 1);
      expect(cubit.state.notice, VerifyEmailNotice.sent);
      expect(cubit.state.waitLeft, const Duration(minutes: 2));
      expect(cubit.state.canResend, isFalse);

      await cubit.resend();
      expect(accounts.linkResends, 1);
    });

    test('an expired link sends at once, wait or no wait', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts);
      await cubit.load();
      await cubit.resend();
      await cubit.sendNow();
      expect(accounts.linkResends, 2);
      expect(cubit.state.waitLeft, const Duration(minutes: 5));
    });

    test('too many requests count as sent', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          emailActionResults: const [Err(RateLimitFailure())],
        ),
      );
      await cubit.load();
      await cubit.resend();
      expect(cubit.state.failure, isNull);
      expect(cubit.state.notice, VerifyEmailNotice.sent);
    });

    test('a failed resend says so and retries', () async {
      final accounts = FakeAccountRepository(
        emailActionResults: const [Err(NetworkFailure()), Ok(null)],
      );
      final cubit = cubitWith(accounts);
      await cubit.load();
      await cubit.resend();
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.waiting, isFalse);

      await cubit.retry();
      expect(accounts.linkResends, 2);
      expect(cubit.state.failure, isNull);
    });

    test('correcting starts from the current address', () async {
      final cubit = cubitWith(FakeAccountRepository());
      await cubit.load();
      cubit.startEditing();
      expect(cubit.state.mode, VerifyEmailMode.edit);
      expect(cubit.state.draft, 'user@example.com');
      cubit.cancelEditing();
      expect(cubit.state.mode, VerifyEmailMode.view);
    });

    test(
      'an incomplete address errs on sending, and editing clears it',
      () async {
        final accounts = FakeAccountRepository();
        final cubit = cubitWith(accounts);
        await cubit.load();
        cubit
          ..startEditing()
          ..draftChanged('user@example');
        expect(cubit.state.showsFieldError, isFalse);

        await cubit.change();
        expect(cubit.state.showsFieldError, isTrue);
        expect(accounts.changedEmails, isEmpty);

        cubit.draftChanged('user@example.co');
        expect(cubit.state.showsFieldError, isFalse);
      },
    );

    test('the same address just goes back', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts);
      await cubit.load();
      cubit
        ..startEditing()
        ..draftChanged('USER@example.com');
      await cubit.change();
      expect(accounts.changedEmails, isEmpty);
      expect(cubit.state.mode, VerifyEmailMode.view);
    });

    test('a new address: sent there, and the waits start over', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts);
      await cubit.load();
      await cubit.resend();
      cubit
        ..startEditing()
        ..draftChanged(' new@example.com ');
      await cubit.change();

      expect(accounts.changedEmails, ['new@example.com']);
      expect(cubit.state.email, 'new@example.com');
      expect(cubit.state.mode, VerifyEmailMode.view);
      expect(cubit.state.notice, VerifyEmailNotice.sent);
      expect(cubit.state.waitLeft, const Duration(minutes: 1));
      expect(cubit.state.sends, 1);
    });

    test('an address with an account is information, not an error', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          emailActionResults: const [Err(ConflictFailure())],
        ),
      );
      await cubit.load();
      cubit
        ..startEditing()
        ..draftChanged('taken@example.com');
      await cubit.change();
      expect(cubit.state.taken, isTrue);
      expect(cubit.state.showsFieldError, isFalse);
      expect(cubit.state.mode, VerifyEmailMode.edit);

      cubit.draftChanged('taken2@example.com');
      expect(cubit.state.taken, isFalse);
    });

    test('a failed correction retries the correction', () async {
      final accounts = FakeAccountRepository(
        emailActionResults: const [Err(NetworkFailure()), Ok(null)],
      );
      final cubit = cubitWith(accounts);
      await cubit.load();
      cubit
        ..startEditing()
        ..draftChanged('new@example.com');
      await cubit.change();
      expect(cubit.state.failure, isA<NetworkFailure>());

      await cubit.retry();
      expect(accounts.changedEmails, hasLength(2));
      expect(accounts.linkResends, 0);
      expect(cubit.state.email, 'new@example.com');
    });

    test('no mail app says so', () async {
      final mail = _FakeMailApp(opens: false);
      final cubit = cubitWith(FakeAccountRepository(), mail: mail);
      await cubit.load();
      await cubit.openMailApp();
      expect(mail.calls, 1);
      expect(cubit.state.notice, VerifyEmailNotice.noMailApp);
    });

    test('opening the sheet starts it clean, keeping the wait', () async {
      final cubit = cubitWith(FakeAccountRepository());
      await cubit.load();
      await cubit.resend();
      cubit
        ..startEditing()
        ..sheetOpened();
      expect(cubit.state.mode, VerifyEmailMode.view);
      expect(cubit.state.notice, isNull);
      expect(cubit.state.waiting, isTrue);
    });
  });

  group('EmailLinkCubit', () {
    EmailLinkCubit link(FakeAccountRepository accounts, [String token = 't']) {
      final cubit = EmailLinkCubit(accounts, token: token);
      addTearDown(cubit.close);
      return cubit;
    }

    test('a good link confirms', () async {
      final accounts = FakeAccountRepository();
      final cubit = link(accounts);
      await cubit.verify();
      expect(accounts.verifiedTokens, ['t']);
      expect(cubit.state.view, EmailLinkView.verified);
    });

    test('out of date, or with no token, asks for a new one', () async {
      final expired = link(
        FakeAccountRepository(verifyResults: const [Err(LinkExpiredFailure())]),
      );
      await expired.verify();
      expect(expired.state.view, EmailLinkView.expired);

      final accounts = FakeAccountRepository();
      final empty = link(accounts, '');
      await empty.verify();
      expect(accounts.verifiedTokens, isEmpty);
      expect(empty.state.view, EmailLinkView.expired);
    });

    test('a failure leaves a retry', () async {
      final cubit = link(
        FakeAccountRepository(
          verifyResults: const [Err(NetworkFailure()), Ok(null)],
        ),
      );
      await cubit.verify();
      expect(cubit.state.view, EmailLinkView.failed);
      await cubit.verify();
      expect(cubit.state.view, EmailLinkView.verified);
    });
  });

  group('the widgets', () {
    Future<VerifyEmailCubit> pumpHome(
      WidgetTester tester, {
      FakeAccountRepository? accounts,
      bool sendLink = false,
      bool load = true,
      LayoutCase? layout,
    }) async {
      final cubit = cubitWith(accounts ?? FakeAccountRepository());
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: VerifyEmailHost(
              sendLink: sendLink,
              child: ListView(
                padding: const EdgeInsetsDirectional.all(16),
                children: const [VerifyEmailBanner(), VerifyEmailRow()],
              ),
            ),
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      if (load) {
        await cubit.load();
        await tester.pump();
        await tester.pump(EmailReminderEntrance.delay);
        await tester.pump(AppMotion.fast * 2);
      }
      return cubit;
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('verify_reminder_action'.tr()));
      await tester.pump();
      await tester.pump(AppMotion.sheetIn);
      await tester.pump(const Duration(seconds: 2));
    }

    /// Ends what a sent link starts: the notice and the wait.
    Future<void> runOut(WidgetTester tester, VerifyEmailCubit cubit) async {
      clock = clock.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
    }

    testLayouts('home lays out without overflow', (tester, layout) async {
      await pumpHome(tester, layout: layout);
      expect(tester.takeException(), isNull);
    });

    testLayouts('the sheet lays out without overflow', (tester, layout) async {
      await pumpHome(tester, layout: layout);
      await openSheet(tester);
      expect(tester.takeException(), isNull);
    });

    testLayouts('editing lays out without overflow', (tester, layout) async {
      final cubit = await pumpHome(tester, layout: layout);
      await openSheet(tester);
      cubit
        ..startEditing()
        ..draftChanged('user@example');
      await cubit.change();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    group('the reminder', () {
      testWidgets('comes a moment after home, not with it', (tester) async {
        final cubit = await pumpHome(tester, load: false);
        await cubit.load();
        await tester.pump();
        expect(find.text('verify_reminder'.tr()), findsNothing);

        await tester.pump(EmailReminderEntrance.delay);
        await tester.pump(AppMotion.fast);
        expect(find.text('verify_reminder'.tr()), findsOneWidget);
        await tester.pump(AppMotion.fast);
      });

      testWidgets('hiding folds it, and the row stays', (tester) async {
        await pumpHome(tester);
        await tester.tap(find.byTooltip('verify_reminder_hide'.tr()));
        await tester.pump();
        await tester.pump(AppMotion.fast * 2);
        expect(find.text('verify_reminder'.tr()), findsNothing);
        expect(find.text('account_email_unverified'.tr()), findsOneWidget);
      });

      testWidgets('tapping anywhere on it opens the sheet', (tester) async {
        await pumpHome(tester);
        await tester.tap(find.text('verify_reminder'.tr()));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(VerifyEmailSheet), findsOneWidget);
      });

      testWidgets('confirmed: no reminder, a badge and no arrow', (
        tester,
      ) async {
        await pumpHome(
          tester,
          accounts: FakeAccountRepository(emailResults: const [Ok(_verified)]),
        );
        expect(find.text('verify_reminder'.tr()), findsNothing);
        expect(find.text('account_email_verified'.tr()), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

        await tester.tap(find.text('user@example.com'));
        await tester.pump();
        expect(find.byType(VerifyEmailSheet), findsNothing);
      });

      testWidgets('a guest sees neither', (tester) async {
        final cubit = cubitWith(FakeAccountRepository(), member: false);
        await tester.pumpLocalized(
          BlocProvider.value(
            value: cubit,
            child: const Scaffold(
              body: Column(children: [VerifyEmailBanner(), VerifyEmailRow()]),
            ),
          ),
        );
        await cubit.load();
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('verify_reminder'.tr()), findsNothing);
        expect(find.text('account_email_unverified'.tr()), findsNothing);
      });

      testWidgets('the row opens the sheet until confirmed', (tester) async {
        await pumpHome(tester);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
        await tester.tap(find.text('account_email_unverified'.tr()));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(VerifyEmailSheet), findsOneWidget);
      });
    });

    group('the sheet', () {
      testWidgets('shows the address, and the ways on', (tester) async {
        await pumpHome(tester);
        await openSheet(tester);
        expect(find.text('verify_title'.tr()), findsOneWidget);
        expect(find.text('verify_sent_to'.tr()), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(VerifyEmailSheet),
            matching: find.text('user@example.com'),
          ),
          findsOneWidget,
        );
        expect(find.text('check_email_open'.tr()), findsOneWidget);
        expect(find.text('check_email_resend'.tr()), findsOneWidget);
      });

      testWidgets('resending counts down on its button, then opens again', (
        tester,
      ) async {
        final accounts = FakeAccountRepository();
        final cubit = await pumpHome(tester, accounts: accounts);
        await openSheet(tester);
        await tester.tap(find.text('check_email_resend'.tr()));
        await tester.pump();
        await tester.pump();

        expect(accounts.linkResends, 1);
        expect(find.textContaining('2:00'), findsOneWidget);
        expect(find.text('check_email_resent'.tr()), findsOneWidget);
        expect(find.byType(NoticeCard), findsOneWidget);

        clock = clock.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.textContaining('1:59'), findsOneWidget);

        await tester.pump(VerifyEmailCubit.noticeFor);
        await tester.pump(AppMotion.fast * 2);
        expect(find.text('check_email_resent'.tr()), findsNothing);

        await runOut(tester, cubit);
        expect(find.text('check_email_resend'.tr()), findsOneWidget);
      });

      testWidgets('a failed send says so inside, and retries', (tester) async {
        final accounts = FakeAccountRepository(
          emailActionResults: const [Err(NetworkFailure()), Ok(null)],
        );
        final cubit = await pumpHome(tester, accounts: accounts);
        await openSheet(tester);
        await tester.tap(find.text('check_email_resend'.tr()));
        await tester.pump();
        await tester.pump();
        expect(find.text('verify_send_failed'.tr()), findsOneWidget);
        await tester.pump(AppMotion.fast * 2);

        await tester.tap(find.text('common_retry'.tr()));
        await tester.pump();
        await tester.pump();
        expect(accounts.linkResends, 2);
        expect(find.text('check_email_resent'.tr()), findsOneWidget);
        await runOut(tester, cubit);
      });

      testWidgets('while resending, the app\'s one spinner', (tester) async {
        final accounts = FakeAccountRepository();
        final cubit = await pumpHome(tester, accounts: accounts);
        await openSheet(tester);
        accounts.gate = Completer<void>();
        await tester.tap(find.text('check_email_resend'.tr()));
        await tester.pump();
        expect(find.byType(AppSpinner), findsOneWidget);
        accounts.gate!.complete();
        await tester.pump();
        await tester.pump();
        await runOut(tester, cubit);
      });

      testWidgets('correcting: a field with the address selected', (
        tester,
      ) async {
        await pumpHome(tester);
        await openSheet(tester);
        await tester.tap(find.text('verify_correct'.tr()));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('verify_edit_body'.tr()), findsOneWidget);
        expect(find.text('verify_send_new'.tr()), findsOneWidget);
        expect(find.text('common_cancel'.tr()), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, 'user@example.com');
        expect(field.controller!.selection.start, 0);
        expect(field.controller!.selection.end, 'user@example.com'.length);

        await tester.tap(find.text('common_cancel'.tr()));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('verify_sent_to'.tr()), findsOneWidget);
      });

      testWidgets('an address with an account shows above the field', (
        tester,
      ) async {
        final accounts = FakeAccountRepository(
          emailActionResults: const [Err(ConflictFailure())],
        );
        await pumpHome(tester, accounts: accounts);
        await openSheet(tester);
        await tester.tap(find.text('verify_correct'.tr()));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.enterText(find.byType(TextField), 'taken@example.com');
        await tester.pump();
        await tester.tap(find.text('verify_send_new'.tr()));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('verify_taken'.tr()), findsOneWidget);
      });

      testWidgets('a new address comes back to the first view', (tester) async {
        final cubit = await pumpHome(tester);
        await openSheet(tester);
        await tester.tap(find.text('verify_correct'.tr()));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.enterText(find.byType(TextField), 'new@example.com');
        await tester.pump();
        await tester.tap(find.text('verify_send_new'.tr()));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.descendant(
            of: find.byType(VerifyEmailSheet),
            matching: find.text('new@example.com'),
          ),
          findsOneWidget,
        );
        expect(find.text('check_email_resent'.tr()), findsOneWidget);
        await runOut(tester, cubit);
      });

      testWidgets('confirmed elsewhere: it closes, with no card', (
        tester,
      ) async {
        final cubit = await pumpHome(
          tester,
          accounts: FakeAccountRepository(
            emailResults: const [Ok(_unverified), Ok(_verified)],
          ),
        );
        await openSheet(tester);
        await cubit.load();
        await tester.pump();
        await tester.pump(AppMotion.sheetOut * 2);
        expect(find.byType(VerifyEmailSheet), findsNothing);
        expect(find.text('verify_done'.tr()), findsNothing);
        expect(find.text('account_email_verified'.tr()), findsOneWidget);
      });

      testWidgets('asked to send: opens and sends at once', (tester) async {
        final accounts = FakeAccountRepository();
        final cubit = await pumpHome(
          tester,
          accounts: accounts,
          sendLink: true,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(VerifyEmailSheet), findsOneWidget);
        expect(accounts.linkResends, 1);
        await runOut(tester, cubit);
      });
    });
  });

  group('EmailLinkPage', () {
    late int continues;
    late int newLinks;

    setUp(() {
      continues = 0;
      newLinks = 0;
    });

    Future<void> pumpLink(
      WidgetTester tester,
      FakeAccountRepository accounts, {
      String token = 't',
      LayoutCase? layout,
    }) async {
      final cubit = EmailLinkCubit(accounts, token: token);
      addTearDown(cubit.close);
      await cubit.verify();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: EmailLinkPage(
            onContinue: () => continues++,
            onNewLink: () => newLinks++,
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
    }

    testLayouts('confirmed lays out without overflow', (tester, layout) async {
      await pumpLink(tester, FakeAccountRepository(), layout: layout);
      expect(tester.takeException(), isNull);
    });

    testLayouts('expired lays out without overflow', (tester, layout) async {
      await pumpLink(
        tester,
        FakeAccountRepository(),
        token: '',
        layout: layout,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirmed: the badge, the happy guide, and on', (
      tester,
    ) async {
      await pumpLink(tester, FakeAccountRepository());
      expect(find.text('verify_done'.tr()), findsOneWidget);
      expect(find.byType(SuccessBadge), findsOneWidget);
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.happy);
      expect(guide.sparkles, isFalse);

      await tester.tap(find.byType(AppButton));
      expect(continues, 1);
    });

    testWidgets('expired: no blame, and a way to a new link', (tester) async {
      await pumpLink(
        tester,
        FakeAccountRepository(verifyResults: const [Err(LinkExpiredFailure())]),
      );
      expect(find.text('verify_expired'.tr()), findsOneWidget);
      expect(find.byType(SuccessBadge), findsNothing);
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.understand);

      await tester.tap(find.text('new_password_new_link'.tr()));
      expect(newLinks, 1);
    });

    testWidgets('a failure offers a retry', (tester) async {
      await pumpLink(
        tester,
        FakeAccountRepository(
          verifyResults: const [Err(NetworkFailure()), Ok(null)],
        ),
      );
      await tester.tap(find.text('common_retry'.tr()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('verify_done'.tr()), findsOneWidget);
    });

    testWidgets('checking shows the app\'s one spinner', (tester) async {
      final cubit = EmailLinkCubit(FakeAccountRepository(), token: 't');
      addTearDown(cubit.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: EmailLinkPage(onContinue: () {}, onNewLink: () {}),
        ),
      );
      await tester.pump();
      expect(find.byType(AppSpinner), findsOneWidget);
    });

    testWidgets('the system\'s back goes on', (tester) async {
      await pumpLink(tester, FakeAccountRepository());
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(continues, 1);
    });

    testWidgets('under reduce motion, all is simply there', (tester) async {
      final cubit = EmailLinkCubit(FakeAccountRepository(), token: 't');
      addTearDown(cubit.close);
      await cubit.verify();
      await tester.pumpLocalized(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: BlocProvider.value(
            value: cubit,
            child: EmailLinkPage(onContinue: () {}, onNewLink: () {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('verify_done'.tr()), findsOneWidget);
      expect(find.byType(SuccessBadge), findsOneWidget);
    });
  });
}
