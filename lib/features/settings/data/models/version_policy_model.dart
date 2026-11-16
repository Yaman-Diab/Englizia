import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/settings/domain/entities/app_version.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';

/// The versions of `GET /api/v1/app/system/config` (`SystemConfigDto`,
/// docs/api/openapi.json), for this phone's platform as `X-Platform` names
/// it; the phone keeps them in the same shape for an open without a
/// connection.
final class VersionPolicyModel {
  const VersionPolicyModel(this.entity);

  factory VersionPolicyModel.fromJson(Map<String, Object?>? json) =>
      VersionPolicyModel(
        VersionPolicy(
          minimum: AppVersion.tryParse(json?.readString('minSupportedVersion')),
          recommended: AppVersion.tryParse(json?.readString('latestVersion')),
          updateUrl: _link(json?.readString('storeUrl')),
        ),
      );

  final VersionPolicy entity;

  Map<String, Object?> toJson() => {
    'minSupportedVersion': ?entity.minimum?.toString(),
    'latestVersion': ?entity.recommended?.toString(),
    'storeUrl': ?entity.updateUrl?.toString(),
  };

  /// A web page only: it is shown to be copied when no store opens.
  static Uri? _link(String? text) {
    final link = Uri.tryParse(text?.trim() ?? '');
    return link != null && link.isScheme('https') && link.host.isNotEmpty
        ? link
        : null;
  }
}
