import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';

abstract interface class SettingsRepository {
  /// The effective settings. Read once per app session and kept: a change
  /// in the control panel arrives at the next open (server doc §17.1).
  Future<Result<EffectiveSettings>> getSettings();
}
