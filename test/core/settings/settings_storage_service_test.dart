import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsStorageService> storage() async {
    SharedPreferences.setMockInitialValues({});
    return SettingsStorageService(await SharedPreferences.getInstance());
  }

  test('the installation id is a UUID made once and kept', () async {
    final settings = await storage();

    final first = await settings.installationId();
    final second = await settings.installationId();

    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
    expect(second, first);
  });

  test('each install gets its own id', () async {
    final a = await (await storage()).installationId();
    final b = await (await storage()).installationId();
    expect(a, isNot(b));
  });
}
