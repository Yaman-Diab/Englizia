import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/notifications/presentation/banner/cubit/in_app_notifications_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's notifications cubit, which the tabs' bar reads for «أنا»'s dot.
Future<InAppNotificationsCubit> inAppNotifications({
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final cubit = InAppNotificationsCubit(
    SettingsStorageService(await SharedPreferences.getInstance()),
  );
  addTearDown(cubit.close);
  return cubit;
}
