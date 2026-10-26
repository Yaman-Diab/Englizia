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
import 'package:google_fonts/google_fonts.dart';

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

  // Fonts ship in assets/fonts: no download on first launch, works offline
  // and where Google servers are unreachable.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(_fontLicenses);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await EasyLocalization.ensureInitialized();
  await configureDependencies();

  runApp(
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      fallbackLocale: AppLocales.fallback,
      path: AppLocales.translationsPath,
      useOnlyLangCode: true,
      // Arabic needs its real plural forms (3–10 "few", 11–99 "many").
      ignorePluralRules: false,
      child: const App(),
    ),
  );
  await sl<AppSessionController>().bootstrap();
}

/// SIL OFL requires the license to travel with the fonts; it shows on the
/// licenses screen.
Stream<LicenseEntry> _fontLicenses() async* {
  for (final (font, file) in [
    ('Readex Pro', 'OFL-ReadexPro.txt'),
    ('Andika', 'OFL-Andika.txt'),
  ]) {
    final text = await rootBundle.loadString('assets/fonts/$file');
    yield LicenseEntryWithLineBreaks([font], text);
  }
}
