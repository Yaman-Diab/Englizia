import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';

abstract interface class SettingsRepository {
  /// The effective settings. Read once per app session and kept: a change
  /// in the control panel arrives at the next open (server doc §17.1).
  Future<Result<EffectiveSettings>> getSettings();

  /// This phone's versions from the same settings, else the last ones kept
  /// on the phone (an open without a connection); an error when neither.
  /// [keptOnly] reads the kept ones without asking the server.
  Future<Result<VersionPolicy>> getVersionPolicy({bool keptOnly = false});
}
