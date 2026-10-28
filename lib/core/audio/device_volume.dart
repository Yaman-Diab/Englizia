/// Whether the phone would play the app's sounds out loud: the media volume
/// above zero. Kids mode asks before the guide speaks (S §4.5).
abstract interface class DeviceVolume {
  Future<bool> isMuted();

  /// Emits whenever muted changes, e.g. the side button turned it up.
  Stream<bool> get mutedChanges;
}

/// Until a way to read the volume is chosen (docs/STATUS.md, D-046): the
/// phone is taken as audible, and the muted state never shows.
final class UnknownDeviceVolume implements DeviceVolume {
  const UnknownDeviceVolume();

  @override
  Future<bool> isMuted() async => false;

  @override
  Stream<bool> get mutedChanges => const Stream.empty();
}
