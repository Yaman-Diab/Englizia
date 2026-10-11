import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/app.dart';
import 'package:englizia/app/di.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(details.exception, details.stack, 'FlutterError');
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(error, stackTrace, 'Uncaught error');
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const SizedBox.shrink();
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await EasyLocalization.ensureInitialized();
  await configureDependencies();

  runApp(
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      fallbackLocale: AppLocales.fallback,
      path: AppLocales.translationsPath,
      useOnlyLangCode: true,
      child: const App(),
    ),
  );
  await sl<AppSessionController>().bootstrap();
}
