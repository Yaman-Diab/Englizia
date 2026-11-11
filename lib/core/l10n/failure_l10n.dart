import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_error_codes.dart';

/// User-facing text for a [Failure]. Every failure type has a translated
/// message, so raw backend text never reaches the screen.
extension FailureL10n on Failure {
  String get localizedMessage => switch (this) {
    NetworkFailure() => 'error_network'.tr(),
    StorageFailure() => 'error_storage'.tr(),
    UnauthorizedFailure() => 'error_unauthorized'.tr(),
    ForbiddenFailure(code: ApiErrorCodes.accountDisabled) =>
      'error_account_disabled'.tr(),
    ForbiddenFailure() => 'error_forbidden'.tr(),
    NotFoundFailure() => 'error_not_found'.tr(),
    ConflictFailure(code: ApiErrorCodes.emailTaken) => 'error_email_taken'.tr(),
    ConflictFailure(code: ApiErrorCodes.externalLoginConflict) =>
      'error_login_conflict'.tr(),
    ConflictFailure() => 'error_conflict'.tr(),
    LinkExpiredFailure() => 'error_link_expired'.tr(),
    ValidationFailure() => 'error_validation'.tr(),
    RateLimitFailure() => 'error_rate_limit'.tr(),
    ServerFailure() => 'error_server'.tr(),
    ProviderFailure() => 'error_provider'.tr(),
    UnknownFailure() => 'error_unknown'.tr(),
  };
}
