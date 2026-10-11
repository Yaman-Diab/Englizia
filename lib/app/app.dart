import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/router/app_router.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/design_system/app_theme.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/core/settings/settings_state.dart';
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
  late final GoRouter _router = createAppRouter(sl<AppSessionController>());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sl<CurrentLanguage>().code = context.locale.languageCode;
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic =
        context.locale.languageCode == AppLocales.arabic.languageCode;
    return BlocProvider(
      create: (_) => sl<SettingsCubit>(),
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
            builder: (context, child) => _AppFrame(child: child),
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
