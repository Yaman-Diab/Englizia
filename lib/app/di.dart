import 'package:englizia/core/di/service_locator.dart';

/// DI composition root. `main()` and `test/di/di_test.dart` call this same
/// function, so a missing registration fails a test, not a device.
Future<void> configureDependencies() async {
  await setupCoreDependencies(sl);
  // Each feature adds one line here: register<Feature>Dependencies(sl);
}
