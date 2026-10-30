import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/domain/entities/password_link.dart';
import 'package:englizia/features/account/presentation/new_password/cubit/new_password_cubit.dart';
import 'package:englizia/features/account/presentation/new_password/pages/new_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_accounts.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

final _memberBody =
    jsonDecode(File(AccountFakeDataSource.registerAsset).readAsStringSync())
        as Map<String, Object?>;

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  setUpAll(initLocalizationForTests);

  const link = PasswordLink(token: 't-1', email: 'user@example.com');
  const goodPassword = 'password1';

  NewPasswordCubit cubitWith(
    FakeAccountRepository accounts, {
    PasswordLink from = link,
  }) {
    final cubit = NewPasswordCubit(accounts, link: from);
    addTearDown(cubit.close);
    return cubit;
  }

  group('data', () {
    late FakeHttpAdapter adapter;
    String? savedDevice;

    AccountRepositoryImpl repository(FakeResponse Function() answer) {
      adapter = FakeHttpAdapter((_) => answer());
      return AccountRepositoryImpl(
        AccountRemoteDataSourceImpl(
          ApiClient(
            Dio(BaseOptions(baseUrl: 'https://api.test'))
              ..httpClientAdapter = adapter,
          ),
        ),
        tokens: FakeTokenStorage(),
        installationId: () async => 'i',
        savedDeviceId: () => savedDevice,
        saveDeviceId: (id) async => savedDevice = id,
        devicePlatform: 'android',
      );
    }

    setUp(() => savedDevice = null);

    test('checks the link with its token', () async {
      final result = await repository(
        () => const FakeResponse(200),
      ).verifyPasswordLink('t-1');

      expect(result, isA<Ok<void>>());
      final request = adapter.requests.single;
      expect(request.path, '/api/v1/auth/password/reset/verify');
      expect(request.data, {'token': 't-1'});
    });

    test('a link out of date is its own failure, checked or saved', () async {
      final repo = repository(() => const FakeResponse(410));
      final checked = await repo.verifyPasswordLink('t-1');
      final saved = await repo.resetPassword(
        token: 't-1',
        password: goodPassword,
      );
      expect((checked as Err).failure, isA<LinkExpiredFailure>());
      expect((saved as Err).failure, isA<LinkExpiredFailure>());
    });

    test('saving sends the password with this phone\'s device', () async {
      savedDevice = 'device-1';
      final result = await repository(
        () => FakeResponse(200, body: _memberBody),
      ).resetPassword(token: 't-1', password: goodPassword);

      final request = adapter.requests.single;
      expect(request.path, '/api/v1/auth/password/reset');
      expect(request.data, {
        'token': 't-1',
        'password': goodPassword,
        'deviceId': 'device-1',
        'platform': 'android',
      });
      expect((result as Ok<AuthTokens?>).value?.kind, AccountKind.member);
      expect(savedDevice, '00000000-0000-4000-8000-000000000000');
    });

    test('a changed password with no session is still a success', () async {
      final result = await repository(
        () => const FakeResponse(200),
      ).resetPassword(token: 't-1', password: goodPassword);
      expect((result as Ok<AuthTokens?>).value, isNull);
    });

    test('a refused password names the field', () async {
      final result = await repository(
        () => const FakeResponse(
          400,
          body: {
            'statusCode': 400,
            'error': {
              'code': 'validation.failed',
              'details': [
                {'field': 'password', 'code': 'too_short', 'message': 'x'},
              ],
            },
          },
        ),
      ).resetPassword(token: 't-1', password: goodPassword);
      final failure = (result as Err).failure as ValidationFailure;
      expect(failure.firstCodeFor('password'), 'too_short');
    });

    test('the token never prints', () {
      expect(link.toString(), isNot(contains('t-1')));
    });

    group('mock mode', () {
      final fake = AccountFakeDataSource(_DiskBundle(), latency: Duration.zero);

      test('opens any link but the expired one', () async {
        await fake.verifyPasswordLink('t-1');
        await expectLater(
          fake.verifyPasswordLink(AccountFakeDataSource.expiredResetToken),
          throwsA(isA<ApiException>()),
        );
      });

      test('saves, or finds no connection for the offline link', () async {
        expect(await fake.resetPassword({'token': 't-1'}), isNotNull);
        await expectLater(
          fake.resetPassword({
            'token': AccountFakeDataSource.unreachableResetToken,
          }),
          throwsA(isA<NetworkException>()),
        );
      });
    });
  });

  group('NewPasswordCubit', () {
    test('a good link opens the form', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts);
      expect(cubit.state.phase, NewPasswordPhase.verifying);
      expect(cubit.state.email, 'user@example.com');

      await cubit.verify();
      expect(accounts.linkChecks, ['t-1']);
      expect(cubit.state.phase, NewPasswordPhase.form);
    });

    test('a link out of date asks for a new one', () async {
      final cubit = cubitWith(
        FakeAccountRepository(linkResults: const [Err(LinkExpiredFailure())]),
      );
      await cubit.verify();
      expect(cubit.state.phase, NewPasswordPhase.expired);
      expect(cubit.state.failure, isNull);
    });

    test('a link with no token is out of date, with no request', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(
        accounts,
        from: const PasswordLink(token: '', email: ''),
      );
      await cubit.verify();
      expect(accounts.linkChecks, isEmpty);
      expect(cubit.state.phase, NewPasswordPhase.expired);
    });

    test('a failed check keeps waiting for a retry', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          linkResults: const [Err(NetworkFailure()), Ok(null)],
        ),
      );
      await cubit.verify();
      expect(cubit.state.phase, NewPasswordPhase.verifying);
      expect(cubit.state.failure, isA<NetworkFailure>());

      await cubit.verify();
      expect(cubit.state.phase, NewPasswordPhase.form);
      expect(cubit.state.failure, isNull);
    });

    test('saves only a password that meets the rule', () async {
      final accounts = FakeAccountRepository();
      final cubit = cubitWith(accounts);
      await cubit.verify();

      cubit.changed('1234567');
      expect(cubit.state.ruleMet, isFalse);
      expect(cubit.state.canSave, isFalse);
      await cubit.save();
      expect(accounts.newPasswords, isEmpty);

      cubit.changed('12345678');
      expect(cubit.state.canSave, isTrue);
      await cubit.save();
      expect(accounts.newPasswords, [('t-1', '12345678')]);
      expect(cubit.state.saved, isTrue);
      expect(cubit.state.session, memberTokens);
    });

    test('a password changed with no session still moves on', () async {
      final cubit = cubitWith(
        FakeAccountRepository(newPasswordResults: const [Ok(null)]),
      );
      await cubit.verify();
      cubit.changed(goodPassword);
      await cubit.save();
      expect(cubit.state.saved, isTrue);
      expect(cubit.state.session, isNull);
    });

    test('a link that ran out while typing asks for a new one', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          newPasswordResults: const [Err(LinkExpiredFailure())],
        ),
      );
      await cubit.verify();
      cubit.changed(goodPassword);
      await cubit.save();
      expect(cubit.state.phase, NewPasswordPhase.expired);
      expect(cubit.state.saving, isFalse);
    });

    test('a refused password is an error until it is edited', () async {
      final cubit = cubitWith(
        FakeAccountRepository(
          newPasswordResults: const [Err(ValidationFailure())],
        ),
      );
      await cubit.verify();
      cubit.changed(goodPassword);
      await cubit.save();
      expect(cubit.state.refused, isTrue);
      expect(cubit.state.refusals, 1);
      expect(cubit.state.canSave, isFalse);

      cubit.changed('${goodPassword}2');
      expect(cubit.state.refused, isFalse);
      expect(cubit.state.canSave, isTrue);
    });

    test('a failed connection keeps the password for a retry', () async {
      final accounts = FakeAccountRepository(
        newPasswordResults: const [Err(NetworkFailure()), Ok(memberTokens)],
      );
      final cubit = cubitWith(accounts);
      await cubit.verify();
      cubit.changed(goodPassword);

      await cubit.save();
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.password, goodPassword);

      await cubit.save();
      expect(cubit.state.saved, isTrue);
      expect(accounts.newPasswords, hasLength(2));
    });

    test('saving twice sends once', () async {
      final accounts = FakeAccountRepository()..gate = Completer<void>();
      final cubit = cubitWith(accounts);
      accounts.gate!.complete();
      await cubit.verify();
      cubit.changed(goodPassword);
      accounts.gate = Completer<void>();

      unawaited(cubit.save());
      await cubit.save();
      expect(accounts.newPasswords, hasLength(1));
      accounts.gate!.complete();
    });
  });

  group('NewPasswordPage', () {
    late List<AuthTokens?> saved;
    late int closes;
    late int newLinks;

    setUp(() {
      saved = [];
      closes = 0;
      newLinks = 0;
    });

    Future<NewPasswordCubit> pumpPage(
      WidgetTester tester, {
      FakeAccountRepository? accounts,
      bool verified = true,
      LayoutCase? layout,
    }) async {
      final cubit = cubitWith(accounts ?? FakeAccountRepository());
      if (verified) await cubit.verify();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: NewPasswordPage(
            onClose: () => closes++,
            onNewLink: () => newLinks++,
            onSaved: saved.add,
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

    AppButton button(WidgetTester tester) =>
        tester.widget<AppButton>(find.byType(AppButton));

    testLayouts('the form lays out without overflow', (tester, layout) async {
      await pumpPage(tester, layout: layout);
      await tester.enterText(find.byType(TextField), goodPassword);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testLayouts('checking lays out without overflow', (tester, layout) async {
      await pumpPage(tester, verified: false, layout: layout);
      expect(tester.takeException(), isNull);
    });

    testLayouts('an expired link lays out without overflow', (
      tester,
      layout,
    ) async {
      await pumpPage(
        tester,
        accounts: FakeAccountRepository(
          linkResults: const [Err(LinkExpiredFailure())],
        ),
        layout: layout,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('while the link is checked, no field and no way to save', (
      tester,
    ) async {
      await pumpPage(tester, verified: false);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.text('new_password_title'.tr()), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('a failed check offers a retry instead of the field', (
      tester,
    ) async {
      final accounts = FakeAccountRepository(
        linkResults: const [Err(NetworkFailure()), Ok(null)],
      );
      await pumpPage(tester, accounts: accounts);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(AppSpinner), findsNothing);

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(accounts.linkChecks, hasLength(2));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('closes instead of going back, with no keyboard at first', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.byTooltip('common_back'.tr()), findsNothing);
      await tester.tap(find.byTooltip('common_close'.tr()));
      expect(closes, 1);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('the button waits for the rule, and the rule is never red', (
      tester,
    ) async {
      await pumpPage(tester);
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.focused);
      expect(button(tester).onPressed, isNull);
      final rule = find.text('account_password_rule'.plural(8));
      expect(rule, findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234567');
      await settle(tester);
      expect(button(tester).onPressed, isNull);
      expect(find.byType(AppIconView), findsWidgets);
      final hint = tester.widgetList<AppIconView>(find.byType(AppIconView));
      expect(hint.map((i) => i.icon), isNot(contains(AppIcon.errorCircle)));
      expect(hint.map((i) => i.icon), contains(AppIcon.circle));

      await tester.enterText(find.byType(TextField), '12345678');
      await settle(tester);
      expect(button(tester).onPressed, isNotNull);
      final met = tester.widgetList<AppIconView>(find.byType(AppIconView));
      expect(met.map((i) => i.icon), contains(AppIcon.checkCircle));
    });

    testWidgets('saved: the next step gets the session', (tester) async {
      await pumpPage(tester);
      await tester.enterText(find.byType(TextField), goodPassword);
      await settle(tester);
      await tester.tap(find.text('new_password_submit'.tr()));
      await settle(tester);
      expect(saved, [memberTokens]);
    });

    testWidgets('while saving, the field and close are shut', (tester) async {
      final accounts = FakeAccountRepository();
      await pumpPage(tester, accounts: accounts);
      await tester.enterText(find.byType(TextField), goodPassword);
      await settle(tester);

      accounts.gate = Completer<void>();
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(button(tester).isLoading, isTrue);
      expect(
        tester.widget<IconButton>(find.byType(IconButton).first).onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);

      accounts.gate!.complete();
      await settle(tester);
      expect(saved, hasLength(1));
    });

    testWidgets('a failed connection says so and retries', (tester) async {
      final accounts = FakeAccountRepository(
        newPasswordResults: const [Err(NetworkFailure()), Ok(memberTokens)],
      );
      await pumpPage(tester, accounts: accounts);
      await tester.enterText(find.byType(TextField), goodPassword);
      await settle(tester);
      await tester.tap(find.byType(AppButton));
      await settle(tester);

      expect(find.text('error_network'.tr()), findsOneWidget);
      expect(find.text(goodPassword), findsOneWidget);

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(saved, [memberTokens]);
    });

    testWidgets('an expired link: no blame, and a way to a new one', (
      tester,
    ) async {
      await pumpPage(
        tester,
        accounts: FakeAccountRepository(
          linkResults: const [Err(LinkExpiredFailure())],
        ),
      );
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.understand);
      expect(find.text('new_password_expired_title'.tr()), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      final icons = tester.widgetList<AppIconView>(find.byType(AppIconView));
      expect(icons.map((i) => i.icon), contains(AppIcon.clock));

      await tester.tap(find.text('new_password_new_link'.tr()));
      expect(newLinks, 1);
    });

    testWidgets('buttons meet the tap target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
