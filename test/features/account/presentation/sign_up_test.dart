import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/presentation/sign_up/cubit/sign_up_cubit.dart';
import 'package:englizia/features/account/presentation/sign_up/pages/sign_up_page.dart';
import 'package:englizia/features/account/presentation/sign_up/widgets/email_suggestions.dart';
import 'package:englizia/features/account/presentation/sign_up/widgets/email_taken_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_accounts.dart';
import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  /// Sessions the page handed on, with the name given.
  late List<(AuthTokens, String)> handedOn;

  setUp(() => handedOn = []);

  SignUpCubit cubitWith(FakeAccountRepository accounts) {
    final cubit = SignUpCubit(accounts);
    addTearDown(cubit.close);
    return cubit;
  }

  void fill(
    SignUpCubit cubit, {
    String name = 'Learner',
    String email = 'user@example.com',
    String password = 'password1',
  }) {
    cubit
      ..changed(SignUpField.name, name)
      ..changed(SignUpField.email, email)
      ..changed(SignUpField.password, password);
  }

  group('EmailSuggestions', () {
    test('offers the domains once there is a name before the @', () {
      expect(EmailSuggestions.suggestionsFor(''), isEmpty);
      expect(EmailSuggestions.suggestionsFor('@g'), isEmpty);
      expect(EmailSuggestions.suggestionsFor('user'), [
        'user@gmail.com',
        'user@hotmail.com',
        'user@outlook.com',
      ]);
      expect(EmailSuggestions.suggestionsFor('user@h'), ['user@hotmail.com']);
      expect(EmailSuggestions.suggestionsFor('user@gmail.com'), isEmpty);
      expect(EmailSuggestions.suggestionsFor('user@school.edu'), isEmpty);
    });
  });

  group('SignUpCubit', () {
    test('sends only when every field is filled', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts)
        ..changed(SignUpField.name, 'Learner')
        ..changed(SignUpField.email, 'user@example.com');
      expect(cubit.state.canSubmit, isFalse);

      await cubit.submit();
      expect(accounts.accounts, isEmpty);
    });

    test('an error shows after the field is left, not while typing', () {
      final cubit = cubitWith(FakeAccountRepository())
        ..changed(SignUpField.email, 'user@exa');
      expect(cubit.state.showsError(SignUpField.email), isFalse);

      cubit.left(SignUpField.email);
      expect(cubit.state.showsError(SignUpField.email), isTrue);

      cubit.changed(SignUpField.email, 'user@exam');
      expect(cubit.state.showsError(SignUpField.email), isFalse);
    });

    test('a refused send marks and shakes the wrong fields', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts);
      fill(cubit, email: 'user@example', password: 'short');

      await cubit.submit();

      expect(accounts.accounts, isEmpty);
      expect(cubit.state.invalid, [SignUpField.email, SignUpField.password]);
      expect(cubit.state.showsError(SignUpField.email), isTrue);
      expect(cubit.state.showsError(SignUpField.password), isTrue);
      expect(cubit.state.shakes, {
        SignUpField.email: 1,
        SignUpField.password: 1,
      });
    });

    test('creates the account and hands its session on', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts);
      fill(cubit);

      await cubit.submit();

      expect(accounts.accounts.single.email, 'user@example.com');
      expect(cubit.state.session, memberTokens);
    });

    test('an email with an account offers sign-in, until it changes', () async {
      final cubit = cubitWith(
        FakeAccountRepository(accountResults: const [Err(ConflictFailure())]),
      );
      fill(cubit);

      await cubit.submit();
      expect(cubit.state.emailTaken, isTrue);
      expect(cubit.state.sending, isFalse);
      expect(cubit.state.session, isNull);

      cubit.changed(SignUpField.email, 'other@example.com');
      expect(cubit.state.emailTaken, isFalse);
    });

    test('a field the server refuses is wrong until edited', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          accountResults: const [
            Err(
              ValidationFailure(
                fieldCodes: {
                  'password': ['too_common'],
                },
              ),
            ),
          ],
        ),
      );
      fill(cubit);

      await cubit.submit();
      expect(cubit.state.showsError(SignUpField.password), isTrue);
      expect(cubit.state.shakes[SignUpField.password], 1);

      cubit.changed(SignUpField.password, 'password2');
      expect(cubit.state.showsError(SignUpField.password), isFalse);
    });

    test('a failed connection keeps the form for a retry', () async {
      final accounts = FakeAccountRepository(
        accountResults: const [Err(NetworkFailure()), Ok(memberTokens)],
      );
      final cubit = cubitWith(accounts);
      fill(cubit);

      await cubit.submit();
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.email, 'user@example.com');

      await cubit.submit();
      expect(cubit.state.failure, isNull);
      expect(cubit.state.session, memberTokens);
    });

    test('ignores edits while sending', () async {
      final accounts = FakeAccountRepository()..gate = Completer<void>();
      final cubit = cubitWith(accounts);
      fill(cubit);

      final sending = cubit.submit();
      cubit.changed(SignUpField.email, 'other@example.com');
      expect(cubit.state.email, 'user@example.com');

      accounts.gate!.complete();
      await sending;
    });
  });

  group('SignUpPage', () {
    Future<SignUpCubit> pumpPage(
      WidgetTester tester, {
      FakeAccountRepository? accounts,
      ValueChanged<String>? onSignIn,
      LayoutCase? layout,
    }) async {
      final cubit = cubitWith(accounts ?? FakeAccountRepository());
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: SignUpPage(
            onCreated: (session, name) => handedOn.add((session, name)),
            onSignIn: onSignIn ?? (_) {},
            onBack: () {},
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.settleEntrance(FormEntrance.action + AppMotion.entrance);
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

    Future<void> type(WidgetTester tester, String labelKey, String text) async {
      await tester.enterText(field(labelKey), text);
      await tester.pump();
    }

    AppButton submitButton(WidgetTester tester) => tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'account_create_submit'.tr()),
    );

    testLayouts('lays out without overflow', (tester, layout) async {
      final accounts = FakeAccountRepository(
        accountResults: const [Err(ConflictFailure())],
      );
      final cubit = await pumpPage(tester, accounts: accounts, layout: layout);
      expect(tester.takeException(), isNull);

      fill(cubit, password: 'short');
      cubit.left(SignUpField.password);
      await settle(tester);
      expect(tester.takeException(), isNull);

      fill(cubit);
      await cubit.submit();
      await settle(tester);
      expect(find.byType(EmailTakenCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the button waits until every field is filled', (tester) async {
      await pumpPage(tester);
      expect(submitButton(tester).onPressed, isNull);

      await type(tester, 'account_field_name', 'Learner');
      await type(tester, 'account_field_email', 'user@example.com');
      expect(submitButton(tester).onPressed, isNull);

      await type(tester, 'account_field_password', 'password1');
      expect(submitButton(tester).onPressed, isNotNull);
    });

    testWidgets('the password rule turns green once met', (tester) async {
      await pumpPage(tester);
      final rule = 'account_password_rule'.plural(8);
      expect(find.text(rule), findsOneWidget);
      expect(rule, '8 أحرف على الأقل');

      await type(tester, 'account_field_password', 'password1');
      final cubit = BlocProvider.of<SignUpCubit>(
        tester.element(find.byType(SignUpPage)),
      );
      expect(cubit.state.showsError(SignUpField.password), isFalse);
    });

    testWidgets('a refused send shows the errors and focuses the first', (
      tester,
    ) async {
      await pumpPage(tester);
      await type(tester, 'account_field_name', 'Learner');
      await type(tester, 'account_field_email', 'user@example');
      await type(tester, 'account_field_password', 'password1');

      await tester.tap(find.text('account_create_submit'.tr()));
      await settle(tester);

      expect(find.text('account_email_invalid'.tr()), findsOneWidget);
      final email = tester.widget<TextField>(field('account_field_email'));
      expect(email.focusNode!.hasFocus, isTrue);
    });

    testWidgets('while sending: the spinner, read-only fields, no back', (
      tester,
    ) async {
      final accounts = FakeAccountRepository()..gate = Completer<void>();
      final cubit = await pumpPage(tester, accounts: accounts);
      fill(cubit);
      unawaited(cubit.submit());
      await tester.pump();
      await tester.pump(AppMotion.quick);

      expect(find.byType(AppSpinner), findsOneWidget);
      expect(submitButton(tester).isLoading, isTrue);
      final name = tester.widget<TextField>(field('account_field_name'));
      expect(name.readOnly, isTrue);
      final back = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
      );
      expect(back.onPressed, isNull);
      expect(
        tester.widget<Mascot>(find.byType(Mascot)).expression,
        MascotExpression.focused,
      );

      accounts.gate!.complete();
      await settle(tester);
    });

    testWidgets('a known email offers sign-in with that email', (tester) async {
      String? signedInWith;
      final cubit = await pumpPage(
        tester,
        accounts: FakeAccountRepository(
          accountResults: const [Err(ConflictFailure())],
        ),
        onSignIn: (email) => signedInWith = email,
      );
      fill(cubit);
      await cubit.submit();
      await settle(tester);

      expect(find.text('account_email_taken'.tr()), findsOneWidget);
      await tester.tap(find.text('account_email_taken_sign_in'.tr()));
      expect(signedInWith, 'user@example.com');
    });

    testWidgets('a failed connection says so and retries', (tester) async {
      final accounts = FakeAccountRepository(
        accountResults: const [Err(NetworkFailure()), Ok(memberTokens)],
      );
      final cubit = await pumpPage(tester, accounts: accounts);
      fill(cubit);
      await cubit.submit();
      await settle(tester);

      expect(find.text('error_network'.tr()), findsOneWidget);
      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(accounts.accounts, hasLength(2));
      expect(handedOn, [(memberTokens, 'Learner')]);
    });

    testWidgets('picking a domain completes the email', (tester) async {
      final cubit = await pumpPage(tester);
      await tester.tap(field('account_field_email'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await type(tester, 'account_field_email', 'user');
      await settle(tester);

      await tester.tap(find.text('@gmail.com'));
      await tester.pump();
      expect(cubit.state.email, 'user@gmail.com');
    });

    testWidgets('buttons and links meet the tap target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
