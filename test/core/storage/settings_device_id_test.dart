import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the device id is none at first, then what was saved', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStorageService(
      await SharedPreferences.getInstance(),
    );
    expect(settings.deviceId, isNull);

    await settings.setDeviceId('device-1');
    expect(settings.deviceId, 'device-1');
  });
}
