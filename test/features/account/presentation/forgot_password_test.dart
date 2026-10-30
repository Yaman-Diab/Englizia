import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/presentation/forgot_password/cubit/forgot_password_cubit.dart';
import 'package:englizia/features/account/presentation/forgot_password/pages/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_accounts.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  ForgotPasswordCubit cubitWith(
    FakeAccountRepository accounts, {
    String email = '',
  }) {
    final cubit = ForgotPasswordCubit(accounts, email: email);
    addTearDown(cubit.close);
    return cubit;
  }

  group('data', () {
    test('POST /api/v1/auth/password/forgot with the email alone', () async {
      final adapter = FakeHttpAdapter((_) => const FakeResponse(202));
      final repository = AccountRepositoryImpl(
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

      final result = await repository.requestPasswordReset(
        ' user@example.com ',
      );
      expect(result, isA<Ok<void>>());
      final request = adapter.requests.single;
      expect(request.path, '/api/v1/auth/password/forgot');
      expect(request.data, {'email': 'user@example.com'});
    });
  });

  group('ForgotPasswordCubit', () {
    test('sends only a complete email', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts)..changed('user@example');
      expect(cubit.state.canSubmit, isFalse);
      await cubit.submit();
      expect(accounts.resetRequests, isEmpty);
      expect(cubit.state.showsError, isTrue);

      cubit.changed('user@example.com');
      expect(cubit.state.showsError, isFalse);
      await cubit.submit();
      expect(accounts.resetRequests, ['user@example.com']);
      expect(cubit.state.sent, isTrue);
    });

    test('the error waits for the field to be left', () {
      final cubit = cubitWith(FakeAccountRepository())..changed('user@');
      expect(cubit.state.showsError, isFalse);
      cubit.left();
      expect(cubit.state.showsError, isTrue);
    });

    test('too many requests still move on, telling nothing', () async {
      final cubit = cubitWith(
        FakeAccountRepository(resetResults: const [Err(RateLimitFailure())]),
        email: 'user@example.com',
      );
      await cubit.submit();
      expect(cubit.state.sent, isTrue);
      expect(cubit.state.failure, isNull);
    });

    test('a failed connection keeps the email for a retry', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          resetResults: const [Err(NetworkFailure()), Ok(null)],
        ),
        email: 'user@example.com',
      );
      await cubit.submit();
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.sent, isFalse);
      await cubit.submit();
      expect(cubit.state.sent, isTrue);
    });
  });

  group('ForgotPasswordPage', () {
    late List<String> sent;
    late int googles;

    setUp(() {
      sent = [];
      googles = 0;
    });

    Future<ForgotPasswordCubit> pumpPage(
      WidgetTester tester, {
      FakeAccountRepository? accounts,
      String email = '',
      LayoutCase? layout,
    }) async {
      final cubit = cubitWith(
        accounts ?? FakeAccountRepository(),
        email: email,
      );
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: ForgotPasswordPage(
            onSent: (email) async => sent.add(email),
            onGoogle: () => googles++,
            onBack: () {},
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

    AppButton send(WidgetTester tester) =>
        tester.widget<AppButton>(find.byType(AppButton));

    testLayouts('lays out without overflow', (tester, layout) async {
      final cubit = await pumpPage(tester, layout: layout);
      cubit
        ..changed('user@')
        ..left();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the guide holds a key over the form', (tester) async {
      await pumpPage(tester);
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.focused);
      expect(guide.prop, MascotProp.key);
      expect(find.text('sign_in_forgot'.tr()), findsOneWidget);
    });

    testWidgets('an email from sign-in is ready, with no keyboard', (
      tester,
    ) async {
      await pumpPage(tester, email: 'user@example.com');
      expect(find.text('user@example.com'), findsOneWidget);
      expect(send(tester).onPressed, isNotNull);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
    });

    testWidgets('an incomplete email says so after the field is left', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.enterText(find.byType(TextField), 'user@example');
      await tester.pump();
      expect(send(tester).onPressed, isNull);
      expect(find.textContaining('name@gmail.com'), findsNothing);

      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(find.textContaining('name@gmail.com'), findsOneWidget);
    });

    testWidgets('sent: a check on the button, then the next step', (
      tester,
    ) async {
      await pumpPage(tester, email: 'user@example.com');
      await tester.tap(find.text('forgot_submit'.tr()));
      await tester.pump();
      expect(send(tester).isDone, isTrue);
      expect(sent, isEmpty);

      await tester.pump(AppMotion.verySlow);
      expect(sent, ['user@example.com']);
    });

    testWidgets('while sending, nothing else can be pressed', (tester) async {
      final accounts = FakeAccountRepository()..gate = Completer<void>();
      final cubit = await pumpPage(
        tester,
        accounts: accounts,
        email: 'user@example.com',
      );
      unawaited(cubit.submit());
      await tester.pump();
      expect(send(tester).isLoading, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      final google = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'forgot_google'.tr()),
      );
      expect(google.onPressed, isNull);
      accounts.gate!.complete();
      await settle(tester);
    });

    testWidgets('coming back from the next step opens the form again', (
      tester,
    ) async {
      final cubit = await pumpPage(tester, email: 'user@example.com');
      await cubit.submit();
      await tester.pump();
      expect(send(tester).isDone, isTrue);

      // The next step was opened and closed again.
      await tester.pump(AppMotion.verySlow);
      await tester.pump();
      expect(sent, ['user@example.com']);
      expect(cubit.state.sent, isFalse);
      expect(send(tester).isDone, isFalse);
      expect(send(tester).onPressed, isNotNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
    });

    testWidgets('Google users go back to sign-in', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('forgot_google'.tr()));
      expect(googles, 1);
    });

    testWidgets('a failed connection says so and retries', (tester) async {
      await pumpPage(
        tester,
        accounts: FakeAccountRepository(
          resetResults: const [Err(NetworkFailure()), Ok(null)],
        ),
        email: 'user@example.com',
      );
      await tester.tap(find.text('forgot_submit'.tr()));
      await settle(tester);
      expect(find.text('error_network'.tr()), findsOneWidget);
      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(sent, ['user@example.com']);
    });

    testWidgets('buttons and links meet the tap target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, email: 'user@example.com');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
