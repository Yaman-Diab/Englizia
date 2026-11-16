import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/settings/data/models/version_policy_model.dart';
import 'package:englizia/features/settings/domain/entities/support_links.dart';

/// `supportWhatsapp`, `privacyUrl` and `termsUrl` of `SystemConfigDto`
/// (docs/api/openapi.json); a page that isn't `https` is left out.
final class SupportLinksModel {
  const SupportLinksModel._();

  static SupportLinks fromJson(Map<String, Object?> json) => SupportLinks(
    whatsapp: json.readString('supportWhatsapp'),
    privacy: VersionPolicyModel.webPage(json.readString('privacyUrl')),
    terms: VersionPolicyModel.webPage(json.readString('termsUrl')),
  );
}
