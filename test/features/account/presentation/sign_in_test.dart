import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/account_button.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/notice_card.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/domain/entities/social_provider.dart';
import 'package:englizia/features/account/presentation/sign_in/cubit/sign_in_cubit.dart';
import 'package:englizia/features/account/presentation/sign_in/pages/sign_in_page.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_accounts.dart';
import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  late DateTime clock;
  setUp(() => clock = DateTime.utc(2026, 10, 28, 12));

  SignInCubit cubitWith(FakeAccountRepository accounts, {String email = ''}) {
    final cubit = SignInCubit(accounts, email: email, now: () => clock);
    addTearDown(cubit.close);
    return cubit;
  }

  void fill(SignInCubit cubit, {String password = 'password1'}) => cubit
    ..emailChanged('user@example.com')
    ..passwordChanged(password);

  group('SignInCubit', () {
    test('sends only with both fields filled', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts)..emailChanged('user@example.com');
      expect(cubit.state.canSubmit, isFalse);
      await cubit.submit();
      expect(accounts.signIns, isEmpty);
    });

    test('starts with the email it was handed', () {
      final cubit = cubitWith(FakeAccountRepository(), email: 'a@example.com');
      expect(cubit.state.email, 'a@example.com');
    });

    test('a good pair hands the session on', () async {
      final cubit = cubitWith(FakeAccountRepository());
      fill(cubit);
      await cubit.submit();
      expect(cubit.state.session, memberTokens);
    });

    test('a refused try keeps the email and clears the password', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          signInResults: const [Err(UnauthorizedFailure())],
        ),
      );
      fill(cubit);
      await cubit.submit();

      expect(cubit.state.wrongCredentials, isTrue);
      expect(cubit.state.wrongTries, 1);
      expect(cubit.state.email, 'user@example.com');
      expect(cubit.state.password, isEmpty);
      expect(cubit.state.session, isNull);
    });

    testWidgets('too many tries wait the server\'s time, counted down', (
      tester,
    ) async {
      final cubit = cubitWith(
        FakeAccountRepository(
          signInResults: const [
            Err(RateLimitFailure(retryAfter: Duration(seconds: 3))),
          ],
        ),
      );
      fill(cubit);
      await cubit.submit();
      expect(cubit.state.locked, isTrue);
      expect(cubit.state.waitLeft, const Duration(seconds: 3));
      expect(cubit.state.password, isEmpty);

      cubit.passwordChanged('password1');
      expect(cubit.state.canSubmit, isFalse);

      clock = clock.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(cubit.state.waitLeft, const Duration(seconds: 2));

      clock = clock.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(cubit.state.locked, isFalse);
      expect(cubit.state.lockedUntil, isNull);
      expect(cubit.state.canSubmit, isTrue);
    });

    test('without a wait from the server, the default one', () async {
      final cubit = cubitWith(
        FakeAccountRepository(signInResults: const [Err(RateLimitFailure())]),
      );
      fill(cubit);
      await cubit.submit();
      expect(cubit.state.waitLeft, SignInCubit.defaultWait);
    });

    test('Google is not stopped by the password\'s lock', () async {
      final accounts = FakeAccountRepository(
        signInResults: const [
          Err(RateLimitFailure(retryAfter: Duration(minutes: 5))),
        ],
      );
      final cubit = cubitWith(accounts);
      fill(cubit);
      await cubit.submit();
      expect(cubit.state.locked, isTrue);

      await cubit.signInWithGoogle();
      expect(cubit.state.session, memberTokens);
      expect(cubit.state.signedInWith, SocialProvider.google);
    });

    test('while Google signs in, nothing else starts or changes', () async {
      final accounts = FakeAccountRepository()..gate = Completer<void>();
      final cubit = cubitWith(accounts);
      fill(cubit);

      unawaited(cubit.signInWithGoogle());
      await pumpEventQueue();
      expect(cubit.state.signingInWith, SocialProvider.google);
      cubit.emailChanged('other@example.com');
      await cubit.submit();
      await cubit.signInWithGoogle();

      expect(cubit.state.email, 'user@example.com');
      expect(accounts.signIns, isEmpty);
      expect(accounts.googleSignIns, 1);
      accounts.gate!.complete();
    });

    test('the retry repeats the last way tried', () async {
      final accounts = FakeAccountRepository(
        signInResults: const [Err(NetworkFailure()), Ok(memberTokens)],
        googleResults: const [Err(NetworkFailure())],
      );
      final cubit = cubitWith(accounts);
      fill(cubit);

      await cubit.signInWithGoogle();
      await cubit.submit();
      await cubit.retry();

      expect(accounts.googleSignIns, 1);
      expect(accounts.signIns, hasLength(2));
      expect(cubit.state.signedInWith, isNull);
    });

    test('a failed connection keeps both fields for a retry', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          signInResults: const [Err(NetworkFailure()), Ok(memberTokens)],
        ),
      );
      fill(cubit);
      await cubit.submit();
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.password, 'password1');

      await cubit.submit();
      expect(cubit.state.session, memberTokens);
    });
  });

  group('SignInPage', () {
    late List<AuthTokens> signedIn;
    late List<SocialProvider?> signedInWith;
    late int apples;
    late List<String> forgot;
    late int creates;

    setUp(() {
      signedIn = [];
      signedInWith = [];
      apples = 0;
      forgot = [];
      creates = 0;
    });

    Future<SignInCubit> pumpPage(
      WidgetTester tester, {
      FakeAccountRepository? accounts,
      SocialProvider? lastProvider,
      TargetPlatform? platform,
      LayoutCase? layout,
    }) async {
      final cubit = cubitWith(accounts ?? FakeAccountRepository());
      final page = BlocProvider.value(
        value: cubit,
        child: SignInPage(
          lastProvider: lastProvider,
          onSignedIn: (session, provider) {
            signedIn.add(session);
            signedInWith.add(provider);
          },
          onApple: () => apples++,
          onForgotPassword: forgot.add,
          onCreateAccount: () => creates++,
          onBack: () {},
        ),
      );
      await tester.pumpLocalized(
        platform == null
            ? page
            : Builder(
                builder: (context) => Theme(
                  data: Theme.of(context).copyWith(platform: platform),
                  child: page,
                ),
              ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.pump(const Duration(seconds: 1));
      return cubit;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.slow * 2);
    }

    Finder field(String labelKey) => find.descendant(
      of: find
          .ancestor(of: find.text(labelKey.tr()), matching: find.byType(Column))
          .first,
      matching: find.byType(TextField),
    );

    AppButton submit(WidgetTester tester) =>
        tester.widget<AppButton>(find.byType(AppButton));

    MascotExpression expression(WidgetTester tester) =>
        tester.widget<Mascot>(find.byType(Mascot)).expression;

    testLayouts('fits while Google signs in', (tester, layout) async {
      final accounts = FakeAccountRepository()..gate = Completer<void>();
      await pumpPage(
        tester,
        accounts: accounts,
        layout: layout,
        platform: TargetPlatform.iOS,
        lastProvider: SocialProvider.google,
      );
      await tester.tap(find.text('sign_in_google'.tr()));
      await tester.pump();
      await tester.pump(AppMotion.slow);

      expect(find.text('sign_in_signing_in'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
      accounts.gate!.complete();
    });

    testLayouts('lays out without overflow', (tester, layout) async {
      final cubit = await pumpPage(
        tester,
        layout: layout,
        lastProvider: SocialProvider.google,
        accounts: FakeAccountRepository(
          signInResults: const [Err(UnauthorizedFailure())],
        ),
      );
      expect(tester.takeException(), isNull);
      fill(cubit, password: 'wrong');
      await cubit.submit();
      await settle(tester);
      expect(find.byType(NoticeCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Google first; Apple only on iOS, and first there', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('sign_in_google'.tr()), findsOneWidget);
      expect(find.text('sign_in_apple'.tr()), findsNothing);

      await pumpPage(tester, platform: TargetPlatform.iOS);
      expect(
        tester.getTopLeft(find.text('sign_in_apple'.tr())).dy,
        lessThan(tester.getTopLeft(find.text('sign_in_google'.tr())).dy),
      );
      await tester.tap(find.text('sign_in_apple'.tr()));
      expect(apples, 1);
    });

    testWidgets('Google signs in, and says it was Google', (tester) async {
      final accounts = FakeAccountRepository();
      await pumpPage(tester, accounts: accounts);

      await tester.tap(find.text('sign_in_google'.tr()));
      await settle(tester);

      expect(accounts.googleSignIns, 1);
      expect(signedIn, [memberTokens]);
      expect(signedInWith, [SocialProvider.google]);
    });

    testWidgets('while Google signs in: its button waits, the rest too', (
      tester,
    ) async {
      final accounts = FakeAccountRepository()..gate = Completer<void>();
      final cubit = await pumpPage(
        tester,
        accounts: accounts,
        platform: TargetPlatform.iOS,
      );

      await tester.tap(find.text('sign_in_google'.tr()));
      await tester.pump();

      final google = tester.widget<AccountButton>(
        find.widgetWithText(AccountButton, 'sign_in_signing_in'.tr()),
      );
      expect(google.isLoading, isTrue);
      expect(find.text('sign_in_google'.tr()), findsNothing);
      final apple = tester.widget<AccountButton>(
        find.widgetWithText(AccountButton, 'sign_in_apple'.tr()),
      );
      expect(apple.onPressed, isNull);
      expect(apple.isLoading, isFalse);
      expect(cubit.state.canSubmit, isFalse);
      // The fields can't take the focus, which would fold the button away.
      await tester.tap(field('account_field_email'), warnIfMissed: false);
      await tester.pump();
      expect(
        find.text('sign_in_signing_in'.tr()).hitTestable(),
        findsOneWidget,
      );
      // A second press opens no second sheet.
      await tester.tap(find.text('sign_in_signing_in'.tr()));
      expect(accounts.googleSignIns, 1);

      accounts.gate!.complete();
      await settle(tester);
      expect(signedIn, [memberTokens]);
    });

    testWidgets('Google\'s sheet closed: back as it was, nothing said', (
      tester,
    ) async {
      await pumpPage(
        tester,
        accounts: FakeAccountRepository(googleResults: const [Ok(null)]),
      );

      await tester.tap(find.text('sign_in_google'.tr()));
      await settle(tester);

      expect(signedIn, isEmpty);
      expect(find.text('sign_in_google'.tr()), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Google failed for the connection: the retry is Google\'s', (
      tester,
    ) async {
      final accounts = FakeAccountRepository(
        googleResults: const [Err(NetworkFailure()), Ok(googleSession)],
      );
      await pumpPage(tester, accounts: accounts);

      await tester.tap(find.text('sign_in_google'.tr()));
      await settle(tester);
      expect(find.text('error_network'.tr()), findsOneWidget);

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(accounts.googleSignIns, 2);
      expect(accounts.signIns, isEmpty);
      expect(signedInWith, [SocialProvider.google]);
    });

    testWidgets('an account Google can\'t join says why, with no retry', (
      tester,
    ) async {
      await pumpPage(
        tester,
        accounts: FakeAccountRepository(
          googleResults: const [
            Err(ConflictFailure(code: ApiErrorCodes.emailTaken)),
          ],
        ),
      );

      await tester.tap(find.text('sign_in_google'.tr()));
      await settle(tester);

      expect(find.text('error_email_taken'.tr()), findsOneWidget);
      expect(find.text('common_retry'.tr()), findsNothing);
    });

    testWidgets('Google missing on the phone says to use another way', (
      tester,
    ) async {
      await pumpPage(
        tester,
        accounts: FakeAccountRepository(
          googleResults: const [Err(ProviderFailure())],
        ),
      );

      await tester.tap(find.text('sign_in_google'.tr()));
      await settle(tester);

      expect(find.text('error_provider'.tr()), findsOneWidget);
    });

    testWidgets('the last way used is badged', (tester) async {
      await pumpPage(tester, lastProvider: SocialProvider.google);
      final google = tester.widget<AccountButton>(
        find.widgetWithText(AccountButton, 'sign_in_google'.tr()),
      );
      expect(google.badge, 'sign_in_last_used'.tr());
    });

    testWidgets('typing folds the providers away; the guide hides its eyes', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.tap(field('account_field_password'));
      await settle(tester);
      // Folded away: still there, but neither seen nor reachable.
      expect(find.text('sign_in_google'.tr()).hitTestable(), findsNothing);
      expect(
        tester
            .widget<AccountButton>(
              find.widgetWithText(AccountButton, 'sign_in_google'.tr()),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('sign_in_subtitle'.tr()), findsNothing);
      expect(expression(tester), MascotExpression.cover);

      await tester.tap(find.byTooltip('field_password_show'.tr()));
      await settle(tester);
      expect(expression(tester), MascotExpression.peek);
    });

    testWidgets('the button waits for both fields, then signs in', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(submit(tester).onPressed, isNull);
      await tester.enterText(field('account_field_email'), 'user@example.com');
      await tester.enterText(field('account_field_password'), 'password1');
      await tester.pump();
      expect(submit(tester).onPressed, isNotNull);

      await tester.tap(find.text('sign_in_submit'.tr()));
      await settle(tester);
      expect(signedIn, [memberTokens]);
    });

    testWidgets('a refused try says so once, and the password is typed again', (
      tester,
    ) async {
      await pumpPage(
        tester,
        accounts: FakeAccountRepository(
          signInResults: const [Err(UnauthorizedFailure())],
        ),
      );
      await tester.enterText(field('account_field_email'), 'user@example.com');
      await tester.enterText(field('account_field_password'), 'wrong');
      await tester.pump();
      await tester.tap(find.text('sign_in_submit'.tr()));
      await settle(tester);

      expect(find.text('sign_in_wrong'.tr()), findsOneWidget);
      expect(find.text('sign_in_wrong_hint_google'.tr()), findsOneWidget);
      final password = tester.widget<TextField>(
        field('account_field_password'),
      );
      expect(password.controller!.text, isEmpty);
      expect(password.focusNode!.hasFocus, isTrue);
      expect(
        tester.widget<TextField>(field('account_field_email')).controller!.text,
        'user@example.com',
      );
      expect(expression(tester), MascotExpression.understand);
    });

    testWidgets('too many tries count down on the button', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = await pumpPage(
        tester,
        accounts: FakeAccountRepository(
          signInResults: const [
            Err(
              RateLimitFailure(retryAfter: Duration(minutes: 4, seconds: 59)),
            ),
          ],
        ),
      );
      fill(cubit);
      await cubit.submit();
      await settle(tester);
      expect(find.text('sign_in_locked'.tr()), findsOneWidget);
      expect(
        find.text('حاول بعد ${Unicode.LRI}4:59${Unicode.PDI}'),
        findsOneWidget,
      );
      expect(submit(tester).onPressed, isNull);
      expect(
        tester.getSemantics(find.byType(NoticeCard)),
        isSemantics(value: 'يمكنك المحاولة بعد 5 دقائق', isLiveRegion: true),
      );

      // The wait ends: the countdown stops itself and the button returns.
      clock = clock.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('sign_in_locked'.tr()), findsNothing);
      expect(find.text('sign_in_submit'.tr()), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a failed connection keeps both fields and retries', (
      tester,
    ) async {
      final cubit = await pumpPage(
        tester,
        accounts: FakeAccountRepository(
          signInResults: const [Err(NetworkFailure()), Ok(memberTokens)],
        ),
      );
      fill(cubit);
      await cubit.submit();
      await settle(tester);
      expect(find.text('error_network'.tr()), findsOneWidget);

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(signedIn, [memberTokens]);
    });

    testWidgets('forgot arrives after the fields, not before them', (
      tester,
    ) async {
      await pumpPage(tester);

      final entrance = tester.widget<Entrance>(
        find.ancestor(
          of: find.text('sign_in_forgot'.tr()),
          matching: find.byType(Entrance),
        ),
      );
      expect(entrance.delay, FormEntrance.field(3));
    });

    testWidgets('forgot hands on the email; the switch opens sign-up', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.enterText(field('account_field_email'), ' a@example.com ');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      await tester.tap(find.text('sign_in_forgot'.tr()));
      expect(forgot, ['a@example.com']);

      await tester.tap(
        find.textContaining('account_guest_create'.tr(), findRichText: true),
      );
      expect(creates, 1);
    });

    testWidgets('while signing in: the spinner, read-only fields, no back', (
      tester,
    ) async {
      final accounts = FakeAccountRepository()..gate = Completer<void>();
      final cubit = await pumpPage(tester, accounts: accounts);
      fill(cubit);
      unawaited(cubit.submit());
      await tester.pump();
      expect(submit(tester).isLoading, isTrue);
      expect(
        tester.widget<TextField>(field('account_field_email')).readOnly,
        isTrue,
      );
      accounts.gate!.complete();
      await settle(tester);
    });

    testWidgets('buttons and links meet the tap target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, lastProvider: SocialProvider.google);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
