import 'dart:async';

import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/notifications/push_message.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Where the server's notifications reach the app (ADR 21). The phone shows
/// them itself while the app is away; while it is open, [arrived] hands them
/// to the in-app banner instead.
abstract interface class PushChannel {
  /// Sets the channel up. Never throws: a phone or build without it simply
  /// gets no notifications.
  Future<void> start();

  /// Notifications that came while the app was open.
  Stream<PushMessage> get arrived;

  /// Notifications tapped on the phone while the app was in the background.
  Stream<PushMessage> get opened;

  /// The notification whose tap opened the app from closed, once.
  Future<PushMessage?> launchedBy();

  /// This phone's address for notifications, or null without one yet.
  Future<String?> token();

  /// A new address, when the old one is replaced.
  Stream<String> get tokenChanges;
}

/// Firebase Cloud Messaging, set up from the env file's values
/// (`FIREBASE_*`), so no config file is checked in per platform.
final class FirebasePushChannel implements PushChannel {
  FirebasePushChannel();

  bool _ready = false;

  FirebaseOptions? get _options {
    final (apiKey, appId) = switch (defaultTargetPlatform) {
      TargetPlatform.android => (
        AppConfig.firebaseAndroidApiKey,
        AppConfig.firebaseAndroidAppId,
      ),
      TargetPlatform.iOS => (
        AppConfig.firebaseIosApiKey,
        AppConfig.firebaseIosAppId,
      ),
      _ => ('', ''),
    };
    if (kIsWeb || apiKey.isEmpty || appId.isEmpty) return null;
    if (AppConfig.firebaseProjectId.isEmpty ||
        AppConfig.firebaseSenderId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: AppConfig.firebaseSenderId,
      projectId: AppConfig.firebaseProjectId,
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
          ? AppConfig.iosBundleId
          : null,
    );
  }

  @override
  Future<void> start() async {
    if (_ready) return;
    final options = _options;
    if (options == null) {
      AppLogger.info('Push off: no Firebase values in this build');
      return;
    }
    try {
      await Firebase.initializeApp(options: options);
      // While the app is open the banner shows it, not the phone (iOS).
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions();
      _ready = true;
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Push setup failed');
    }
  }

  static PushMessage? _read(RemoteMessage message) => PushMessage.fromData(
    message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );

  Stream<PushMessage> _messages(Stream<RemoteMessage> Function() source) =>
      _ready
      ? source().map(_read).where((m) => m != null).cast<PushMessage>()
      : const Stream.empty();

  @override
  Stream<PushMessage> get arrived =>
      _messages(() => FirebaseMessaging.onMessage);

  @override
  Stream<PushMessage> get opened =>
      _messages(() => FirebaseMessaging.onMessageOpenedApp);

  @override
  Future<PushMessage?> launchedBy() async {
    if (!_ready) return null;
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message == null ? null : _read(message);
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Reading the opening notification');
      return null;
    }
  }

  @override
  Future<String?> token() async {
    if (!_ready) return null;
    try {
      // A registration token, which FCM's HTTP v1 API sends to. The newer
      // installation ID (register/onRegistered) needs the server's sending
      // to change with it: not agreed yet (docs/api/notifications.md).
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (error, stackTrace) {
      // No Google Play services, or iOS without its APNs key yet.
      AppLogger.error(error, stackTrace, 'No notification token');
      return null;
    }
  }

  @override
  Stream<String> get tokenChanges {
    if (!_ready) return const Stream.empty();
    // As [token]: registration tokens until the server sends by FID.
    // ignore: deprecated_member_use
    return FirebaseMessaging.instance.onTokenRefresh;
  }
}

/// Mock mode (`env/mock.json`): notifications come from the dev page.
final class MockPushChannel implements PushChannel {
  final _arrived = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  /// As if the server sent [message] while the app is open.
  void arrive(PushMessage message) => _arrived.add(message);

  /// As if [message] was tapped on the phone.
  void open(PushMessage message) => _opened.add(message);

  @override
  Future<void> start() async {}

  @override
  Stream<PushMessage> get arrived => _arrived.stream;

  @override
  Stream<PushMessage> get opened => _opened.stream;

  @override
  Future<PushMessage?> launchedBy() async => null;

  @override
  Future<String?> token() async => 'mock-push-token';

  @override
  Stream<String> get tokenChanges => const Stream.empty();
}
