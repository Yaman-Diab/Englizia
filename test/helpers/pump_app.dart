import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_theme.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default phone viewport; also test [narrowViewport] for layout overflows.
const defaultViewport = Size(375, 812);
const narrowViewport = Size(320, 640);

/// Call from `setUpAll` in any test that mounts `EasyLocalization`.
Future<void> initLocalizationForTests() async {
  SharedPreferences.setMockInitialValues({});
  EasyLocalization.logger.enableBuildModes = [];
  await EasyLocalization.ensureInitialized();
}

/// Reads translations straight from disk so tests don't depend on asset
/// bundling timing.
class FileAssetLoader extends AssetLoader {
  const FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

/// Wraps [child] in the app's localization setup with a pinned viewport.
Widget localizedTestRoot({required Locale locale, required Widget child}) =>
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      fallbackLocale: AppLocales.fallback,
      path: AppLocales.translationsPath,
      assetLoader: const FileAssetLoader(),
      startLocale: locale,
      saveLocale: false,
      useOnlyLangCode: true,
      child: child,
    );

/// One layout under test: a supported locale, a phone width, a theme mode.
typedef LayoutCase = ({Locale locale, Size size, ThemeMode themeMode});

/// Registers [body] once per supported locale, phone width
/// ([defaultViewport], [narrowViewport]) and theme mode, named
/// "[description] (ar, 320dp, dark)" — the Definition of Done matrix.
void testLayouts(
  String description,
  Future<void> Function(WidgetTester tester, LayoutCase layout) body,
) {
  for (final locale in AppLocales.supported) {
    for (final size in [defaultViewport, narrowViewport]) {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets(
          '$description (${locale.languageCode}, '
          '${size.width.toInt()}dp, ${themeMode.name})',
          (tester) =>
              body(tester, (locale: locale, size: size, themeMode: themeMode)),
        );
      }
    }
  }
}

extension PumpApp on WidgetTester {
  void setViewport(Size size) {
    view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
  }

  /// Pumps [home] inside localization, ScreenUtil and the app theme.
  Future<void> pumpLocalized(
    Widget home, {
    Locale locale = AppLocales.arabic,
    ThemeMode themeMode = ThemeMode.light,
    Size size = defaultViewport,
  }) async {
    setViewport(size);
    await pumpWidget(
      localizedTestRoot(
        locale: locale,
        child: ScreenUtilInit(
          designSize: AppTheme.designSize,
          minTextAdapt: true,
          builder: (context, _) {
            final isArabic = context.locale.languageCode == 'ar';
            return MaterialApp(
              theme: AppTheme.light(isArabic: isArabic),
              darkTheme: AppTheme.dark(isArabic: isArabic),
              themeMode: themeMode,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: home,
            );
          },
        ),
      ),
    );
    await pumpUntilLocalized();
  }

  /// Plays a staggered entrance to the end ([settled] from
  /// `entrance_choreography.dart`). flutter_animate starts each animation from
  /// a zero-length timer and counts from the next frame, and a bare `pump()`
  /// does not advance the clock, hence the explicit ticks.
  Future<void> settleEntrance(Duration settled) async {
    const tick = Duration(milliseconds: 1);
    await pump(tick); // fires the start timers
    await pump(tick); // first animation frame
    await pump(settled);
    await pump(tick); // timers of anything built meanwhile
  }

  /// Translations load asynchronously; a few frames are enough with
  /// [FileAssetLoader]. Avoids `pumpAndSettle`, which hangs on spinners.
  Future<void> pumpUntilLocalized() async {
    for (var i = 0; i < 5; i++) {
      await pump();
    }
  }
}
