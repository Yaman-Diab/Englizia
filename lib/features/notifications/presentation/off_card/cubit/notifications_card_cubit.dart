import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What «أنا» says about reminders (design "Notifications" 09–10).
enum NotificationsCard {
  /// Nothing to say: they are on, or never put off twice.
  none,

  /// «ليس الآن» twice: «التذكيرات متوقفة» with «فعّلها», the prompt again.
  off,

  /// Wanted, but the phone keeps them off: «افتح الإعدادات».
  system,
}

/// Reads the card's state, again on coming back from the phone's settings or
/// the prompt, where it may have changed.
class NotificationsCardCubit extends Cubit<NotificationsCard> {
  NotificationsCardCubit(this._profiles, this._permission, this._storage)
    : super(NotificationsCard.none);

  final ProfileRepository _profiles;
  final NotificationPermission _permission;
  final SettingsStorageService _storage;

  /// Put off this often, the card offers them again (design 09).
  static const skipsBeforeCard = 2;

  Future<void> check() async {
    final (preferences, access) = await (
      _profiles.getPreferences(),
      _permission.status(),
    ).wait;
    if (isClosed) return;
    final wanted = switch (preferences) {
      Ok(:final value) => value.notifications,
      Err() => false,
    };
    final allowed = access == NotificationAccess.granted;
    emit(switch ((wanted, allowed)) {
      (true, false) => NotificationsCard.system,
      (true, true) => NotificationsCard.none,
      _ when _storage.notificationPromptSkips >= skipsBeforeCard =>
        NotificationsCard.off,
      _ => NotificationsCard.none,
    });
  }

  Future<void> openPhoneSettings() => _permission.openSettings();
}
