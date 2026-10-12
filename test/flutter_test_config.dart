import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Runs before every test file: fonts must come from the bundled assets,
/// exactly as in the app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
