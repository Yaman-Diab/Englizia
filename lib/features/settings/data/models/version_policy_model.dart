import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/settings/domain/entities/app_version.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';

/// One platform's entry of the settings' `appVersion` group; the phone keeps
/// it in the same shape for an open without a connection.
// ASSUMPTION(api): field names proposed, not confirmed (docs/api/settings.md).
final class VersionPolicyModel {
  const VersionPolicyModel(this.entity);

  factory VersionPolicyModel.fromJson(Map<String, Object?>? json) =>
      VersionPolicyModel(
        VersionPolicy(
          minimum: AppVersion.tryParse(json?.readString('minVersion')),
          recommended: AppVersion.tryParse(
            json?.readString('recommendedVersion'),
          ),
          updateUrl: _link(json?.readString('updateUrl')),
        ),
      );

  /// This phone's entry in the whole settings; none for another platform.
  factory VersionPolicyModel.fromSettings(
    Map<String, Object?> settings, {
    required String? platform,
  }) => VersionPolicyModel.fromJson(
    platform == null ? null : settings.readMap('appVersion')?.readMap(platform),
  );

  final VersionPolicy entity;

  Map<String, Object?> toJson() => {
    'minVersion': ?entity.minimum?.toString(),
    'recommendedVersion': ?entity.recommended?.toString(),
    'updateUrl': ?entity.updateUrl?.toString(),
  };

  /// A web page only: it is shown to be copied when no store opens.
  static Uri? _link(String? text) {
    final link = Uri.tryParse(text?.trim() ?? '');
    return link != null && link.isScheme('https') && link.host.isNotEmpty
        ? link
        : null;
  }
}
