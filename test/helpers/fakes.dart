import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/device_volume.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.tokens]);

  AuthTokens? tokens;
  bool throwOnRead = false;

  /// Whether the phone manages to save what is written.
  bool savesWrites = true;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<AuthTokens?> read() async {
    if (throwOnRead) throw StateError('keystore unavailable');
    return tokens;
  }

  @override
  Future<bool> write(AuthTokens tokens) async {
    this.tokens = tokens;
    writeCount++;
    return savesWrites;
  }

  @override
  Future<void> clear() async {
    tokens = null;
    clearCount++;
  }
}

class FakeTokenRefresher implements TokenRefresher {
  FakeTokenRefresher(this._onRefresh);

  final Future<AuthTokens> Function(AuthTokens current) _onRefresh;
  int calls = 0;

  @override
  Future<AuthTokens> refresh(AuthTokens current) {
    calls++;
    return _onRefresh(current);
  }
}

/// Connectivity that tests switch by hand with [online].
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({bool online = true}) : _online = online;

  bool _online;
  final _changes = StreamController<bool>.broadcast();

  set online(bool value) {
    if (value == _online) return;
    _online = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

/// Answers like the phone would: [request] shows the "prompt" once and then
/// keeps the answer, as both platforms do after a refusal.
class FakeNotificationPermission implements NotificationPermission {
  FakeNotificationPermission({
    this.access = NotificationAccess.denied,
    this.answer = NotificationAccess.granted,
  });

  /// The current state.
  NotificationAccess access;

  /// What the learner taps when the prompt shows.
  NotificationAccess answer;
  var prompts = 0;
  var settingsOpened = 0;
  var _asked = false;

  @override
  Future<NotificationAccess> status() async => access;

  @override
  Future<NotificationAccess> request() async {
    if (!_asked && access == NotificationAccess.denied) {
      _asked = true;
      prompts++;
      access = answer;
    }
    return access;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// A phone whose volume the test turns up and down.
class FakeDeviceVolume implements DeviceVolume {
  FakeDeviceVolume({bool muted = false}) : _muted = muted;

  bool _muted;
  final _changes = StreamController<bool>.broadcast();

  bool get muted => _muted;
  set muted(bool value) {
    _muted = value;
    _changes.add(value);
  }

  @override
  Future<bool> isMuted() async => _muted;

  @override
  Stream<bool> get mutedChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

/// Records the sounds asked for; plays nothing.
class FakeSoundPlayer implements SoundPlayer {
  final played = <AppSound>[];

  @override
  Future<void> preload() async {}

  @override
  Future<void> play(AppSound sound) async => played.add(sound);
}
