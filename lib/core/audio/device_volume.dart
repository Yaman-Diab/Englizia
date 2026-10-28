import 'dart:async';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:volume_controller/volume_controller.dart';

/// Whether the phone would play the app's sounds out loud: the media volume
/// above zero. Kids mode asks before the guide speaks (S §4.5).
abstract interface class DeviceVolume {
  Future<bool> isMuted();

  /// Emits whenever muted changes, e.g. the side button turned it up.
  Stream<bool> get mutedChanges;
}

/// The phone's own media volume, through `volume_controller`.
///
/// The plugin keeps one listener for the whole app, so only one stream
/// listener should be active at a time (the kids' welcome is the only
/// one). It never fails the caller: when the volume cannot be read the
/// phone is taken as audible, so a child is never blocked by a plugin error.
final class PlatformDeviceVolume implements DeviceVolume {
  PlatformDeviceVolume([VolumeController? controller])
    : _controller = controller ?? VolumeController.instance;

  final VolumeController _controller;

  @override
  Future<bool> isMuted() async {
    try {
      return _silent(await _controller.getVolume());
    } on Object catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Could not read the volume');
      return false;
    }
  }

  @override
  Stream<bool> get mutedChanges {
    StreamSubscription<double>? source;
    late final StreamController<bool> changes;
    changes = StreamController<bool>(
      onListen: () {
        try {
          source = _controller.addListener(
            (volume) => changes.add(_silent(volume)),
            fetchInitialVolume: false,
          );
        } on Object catch (error, stackTrace) {
          AppLogger.error(error, stackTrace, 'Could not follow the volume');
        }
      },
      onCancel: () async {
        await source?.cancel();
        _controller.removeListener();
        await changes.close();
      },
    );
    return changes.stream.distinct();
  }

  /// Zero is silent; the system's mute switch also reads as zero.
  static bool _silent(double volume) => volume <= 0;
}

/// For tests, and for a phone whose volume cannot be read: always audible,
/// so the muted state never shows.
final class UnknownDeviceVolume implements DeviceVolume {
  const UnknownDeviceVolume();

  @override
  Future<bool> isMuted() async => false;

  @override
  Stream<bool> get mutedChanges => const Stream.empty();
}
