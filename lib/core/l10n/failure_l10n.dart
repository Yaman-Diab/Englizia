import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/error/failure.dart';

/// User-facing text for a [Failure]. Every failure type has a translated
/// message, so raw backend text never reaches the screen.
extension FailureL10n on Failure {
  String get localizedMessage => switch (this) {
    NetworkFailure() => 'error_network'.tr(),
    StorageFailure() => 'error_storage'.tr(),
    UnauthorizedFailure() => 'error_unauthorized'.tr(),
    ForbiddenFailure() => 'error_forbidden'.tr(),
    NotFoundFailure() => 'error_not_found'.tr(),
    ConflictFailure() => 'error_conflict'.tr(),
    ValidationFailure() => 'error_validation'.tr(),
    RateLimitFailure() => 'error_rate_limit'.tr(),
    ServerFailure() => 'error_server'.tr(),
    UnknownFailure() => 'error_unknown'.tr(),
  };
}
