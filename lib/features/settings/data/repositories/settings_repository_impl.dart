import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';

final class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._remote);

  final SettingsRemoteDataSource _remote;
  EffectiveSettings? _loaded;

  /// A success is kept for the session, so each screen that reads a setting
  /// does not fetch it again; a failure is retried by the next call.
  @override
  Future<Result<EffectiveSettings>> getSettings() async {
    if (_loaded case final settings?) return Ok(settings);
    final result = await guard(
      () async => (await _remote.getSettings()).entity,
    );
    if (result case Ok(:final value)) _loaded = value;
    return result;
  }
}
