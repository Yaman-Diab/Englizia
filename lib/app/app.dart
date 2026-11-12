import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/router/app_router.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/router/notification_routes.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/design_system/app_theme.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/notifications/push_channel.dart';
import 'package:englizia/core/notifications/push_message.dart';
import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/core/settings/settings_state.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_cubit.dart';
import 'package:englizia/features/lessons/data/answers_sync.dart';
import 'package:englizia/features/notifications/data/services/push_token_sync.dart';
import 'package:englizia/features/notifications/presentation/banner/cubit/in_app_notifications_cubit.dart';
import 'package:englizia/features/notifications/presentation/banner/widgets/notification_banner_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Root widget. Expects an `EasyLocalization` ancestor (see `main.dart`).
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  /// The opening: the splash shows it, the router waits for it.
  final _launch = sl<SplashCubit>();
  late final GoRouter _router = createAppRouter(
    sl<AppSessionController>(),
    launch: _launch,
  );
  late final AnswersSync _answers;

  /// Notifications that arrive while the app is open (ADR 21).
  final _notifications = sl<InAppNotificationsCubit>();
  final _session = sl<AppSessionController>();
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// A tapped notification waiting for the opening or a sign-in.
  PushMessage? _toOpen;

  @override
  void initState() {
    super.initState();
    unawaited(_launch.start());
    _answers = sl<AnswersSync>()..start();
    _router.routerDelegate.addListener(_onRoute);
    _session.addListener(_openWaiting);
    _subscriptions.add(_launch.stream.listen((_) => _openWaiting()));
    unawaited(_startPush());
  }

  Future<void> _startPush() async {
    final push = sl<PushChannel>();
    await push.start();
    if (!mounted) return;
    _subscriptions
      ..add(
        push.arrived.listen(
          (message) =>
              _notifications.arrived(message, learning: isLearningPath(_path)),
        ),
      )
      ..add(push.opened.listen(_open));
    final first = await push.launchedBy();
    if (first != null && mounted) _open(first);
    sl<PushTokenSync>().start();
  }

  /// The top route's path, a pushed one included.
  String get _path => _router.routerDelegate.currentConfiguration.isEmpty
      ? ''
      : _router.state.uri.path;

  /// «أنا» seen: its dot has done its work.
  void _onRoute() {
    if (_path == AppRoutes.me) unawaited(_notifications.seenMe());
  }

  /// A notification was tapped, on the phone or as the banner.
  void _open(PushMessage message) {
    _toOpen = message;
    _openWaiting();
  }

  /// Opens the tapped notification once nothing stands before it (design
  /// 11): an update to make keeps it waiting on the splash, no account sends
  /// to sign in first.
  void _openWaiting() {
    final message = _toOpen;
    if (message == null || !mounted) return;
    if (_launch.state.launch != LaunchStatus.ready) return;
    if (!_session.hasSession) {
      if (_session.status == SessionStatus.signedOut &&
          _path != AppRoutes.signIn) {
        unawaited(_router.push(AppRoutes.signIn));
      }
      return;
    }
    _toOpen = null;
    if (message.kind == PushKind.teacherReply) {
      unawaited(_notifications.seenMe());
    }
    // After the frame: a sign-in that just ended goes home first, and this
    // must come after it, not be replaced by it.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        final to = notificationDestination(message);
        if (to.push) {
          unawaited(_router.push(to.location, extra: to.extra));
        } else {
          _router.go(to.location, extra: to.extra);
        }
      })
      ..scheduleFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sl<CurrentLanguage>().code = context.locale.languageCode;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _session.removeListener(_openWaiting);
    _router.routerDelegate.removeListener(_onRoute);
    unawaited(_notifications.close());
    _answers.stop();
    _router.dispose();
    unawaited(_launch.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic =
        context.locale.languageCode == AppLocales.arabic.languageCode;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SettingsCubit>()),
        BlocProvider.value(value: _launch),
        BlocProvider.value(value: _notifications),
      ],
      child: ScreenUtilInit(
        designSize: AppTheme.designSize,
        minTextAdapt: true,
        builder: (context, _) => BlocBuilder<SettingsCubit, SettingsState>(
          buildWhen: (previous, current) =>
              previous.themeMode != current.themeMode,
          builder: (context, settings) => MaterialApp.router(
            onGenerateTitle: (_) => 'app_name'.tr(),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(isArabic: isArabic),
            darkTheme: AppTheme.dark(isArabic: isArabic),
            themeMode: settings.themeMode,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            routerConfig: _router,
            builder: (context, child) => _AppFrame(
              child: NotificationBannerHost(
                onOpen: _open,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clamps system text scaling so layouts stay usable, and marks non-prod
/// builds with the environment name.
class _AppFrame extends StatelessWidget {
  const _AppFrame({required this.child});

  static const _minTextScale = 0.9;
  static const _maxTextScale = 1.3;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = MediaQuery.withClampedTextScaling(
      minScaleFactor: _minTextScale,
      maxScaleFactor: _maxTextScale,
      child: child ?? const SizedBox.shrink(),
    );
    if (AppConfig.isProd || AppConfig.appEnv.isEmpty) return content;
    return Banner(
      message: AppConfig.appEnv.toUpperCase(),
      location: BannerLocation.topEnd,
      color: Theme.of(context).colorScheme.tertiary,
      child: content,
    );
  }
}
