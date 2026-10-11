import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory platform plugins so `configureDependencies()` runs in tests.
void mockPlatformPlugins() {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'Englizia',
    packageName: 'com.example.englizia',
    version: '0.0.1',
    buildNumber: '1',
    buildSignature: '',
  );
}
