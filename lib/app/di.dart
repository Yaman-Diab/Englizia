import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/features/onboarding/onboarding_injection.dart';
import 'package:englizia/features/placement/placement_injection.dart';
import 'package:englizia/features/settings/settings_injection.dart';
import 'package:englizia/features/tracks/tracks_injection.dart';

/// DI composition root. `main()` and `test/di/di_test.dart` call this same
/// function, so a missing registration fails a test, not a device.
Future<void> configureDependencies() async {
  await setupCoreDependencies(sl);
  // Each feature adds one line here.
  registerTracksDependencies(sl);
  registerPlacementDependencies(sl);
  registerSettingsDependencies(sl);
  registerOnboardingDependencies(sl);
}
