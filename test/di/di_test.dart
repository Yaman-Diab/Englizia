import 'package:dio/dio.dart';
import 'package:englizia/app/di.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/platform_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(mockPlatformPlugins);
  tearDown(() => sl.reset());

  test('configureDependencies resolves every registration', () async {
    await configureDependencies();

    expect(sl<TokenStorage>(), isNotNull);
    expect(sl<TokenRefresher>(), isNotNull);
    expect(sl<AppSessionController>(), isNotNull);
    expect(sl<Dio>(), isNotNull);
    expect(sl<ApiClient>(), isNotNull);

    final settings = sl<SettingsCubit>();
    expect(sl<SettingsCubit>(), isNot(same(settings)), reason: 'factory');
    await settings.close();
  });
}
