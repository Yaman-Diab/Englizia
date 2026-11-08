import 'package:flutter/foundation.dart';

/// This phone as the server's `DevicePlatform` names it (docs/api/openapi.json),
/// sent with every request that starts or renews a session. Any other platform
/// sends null, which the contract allows.
String? devicePlatform() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  _ => null,
};
