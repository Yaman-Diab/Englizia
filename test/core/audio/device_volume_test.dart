import 'package:englizia/core/audio/device_volume.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The plugin's channels (volume_controller 3.5), played by the test.
const _method = MethodChannel('com.kurenai7968.volume_controller.method');
const _events = EventChannel(
  'com.kurenai7968.volume_controller.volume_listener_event',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late double volume;
  late MockStreamHandlerEventSink? sink;
  var cancelled = false;

  setUp(() {
    volume = .5;
    sink = null;
    cancelled = false;
    messenger.setMockMethodCallHandler(_method, (call) async {
      if (call.method == 'getVolume') return volume;
      throw MissingPluginException();
    });
    messenger.setMockStreamHandler(
      _events,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          expect((arguments! as Map)['fetchInitialVolume'], isFalse);
          sink = events;
        },
        onCancel: (_) => cancelled = true,
      ),
    );
  });
  tearDown(() {
    messenger
      ..setMockMethodCallHandler(_method, null)
      ..setMockStreamHandler(_events, null);
  });

  test('a volume above zero is audible, zero is muted', () async {
    expect(await PlatformDeviceVolume().isMuted(), isFalse);
    volume = 0;
    expect(await PlatformDeviceVolume().isMuted(), isTrue);
  });

  test('a volume that cannot be read counts as audible', () async {
    messenger.setMockMethodCallHandler(_method, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await PlatformDeviceVolume().isMuted(), isFalse);
  });

  test('follows the volume, telling only when muted changes', () async {
    final seen = <bool>[];
    final subscription = PlatformDeviceVolume().mutedChanges.listen(seen.add);
    await pumpEventQueue();

    sink!
      ..success(.4)
      ..success(.3)
      ..success(0.0)
      ..success(0.0)
      ..success(.2);
    await pumpEventQueue();
    expect(seen, [false, true, false]);

    await subscription.cancel();
    expect(cancelled, isTrue);
  });

  test('a missing plugin never breaks the caller', () async {
    messenger.setMockStreamHandler(_events, null);
    final subscription = PlatformDeviceVolume().mutedChanges.listen((_) {});
    await pumpEventQueue();
    await subscription.cancel();
    expect(await const UnknownDeviceVolume().isMuted(), isFalse);
  });
}
