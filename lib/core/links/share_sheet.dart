import 'package:englizia/core/logging/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// The phone's own share sheet, for text the learner sends on.
abstract interface class ShareSheet {
  /// [origin] is where the sheet points from on an iPad, in global
  /// coordinates. False when the phone has no sheet to show.
  Future<bool> share(String text, {Rect? origin});
}

final class PlatformShareSheet implements ShareSheet {
  const PlatformShareSheet();

  @override
  Future<bool> share(String text, {Rect? origin}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
      return result.status != ShareResultStatus.unavailable;
    } on PlatformException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Could not share');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
