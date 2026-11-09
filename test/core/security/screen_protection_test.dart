import 'package:englizia/core/security/screen_protection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const secure = MethodChannel('englizia/screen_secure');
  const capture = EventChannel('englizia/screen_capture');
  late List<Object?> sets;

  setUp(() {
    sets = [];
    messenger.setMockMethodCallHandler(secure, (call) async {
      sets.add(call.arguments);
      return null;
    });
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(secure, null)
      ..setMockStreamHandler(capture, null);
  });

  group('Android', () {
    test('protected while any view holds it, lifted by the last', () async {
      final protection = PlatformScreenProtection(
        platform: TargetPlatform.android,
      );

      final first = protection.protect();
      final second = protection.protect();
      await pumpEventQueue();
      expect(sets, [true]);

      first();
      // Letting go twice doesn't let go of the other view's hold.
      first();
      await pumpEventQueue();
      expect(sets, [true]);

      second();
      await pumpEventQueue();
      expect(sets, [true, false]);
    });

    test('the screen is never «captured»: a recording comes out black', () {
      final protection = PlatformScreenProtection(
        platform: TargetPlatform.android,
      );

      expect(protection.captured, isFalse);
    });

    test('a platform that refuses is simply unprotected', () async {
      messenger.setMockMethodCallHandler(secure, (_) async {
        throw PlatformException(code: 'no');
      });
      final protection = PlatformScreenProtection(
        platform: TargetPlatform.android,
      );

      expect(protection.protect, returnsNormally);
      await pumpEventQueue();
    });
  });

  group('iOS', () {
    test('nothing to set: a screenshot can\'t be stopped there', () async {
      PlatformScreenProtection(platform: TargetPlatform.iOS).protect()();
      await pumpEventQueue();

      expect(sets, isEmpty);
    });

    test('a recording or a mirror is told as it starts and stops', () async {
      late MockStreamHandlerEventSink sink;
      messenger.setMockStreamHandler(
        capture,
        MockStreamHandler.inline(
          onListen: (_, events) {
            sink = events..success(false);
          },
        ),
      );
      final protection = PlatformScreenProtection(platform: TargetPlatform.iOS);
      final seen = <bool>[];
      final watching = protection.capturedChanges.listen(seen.add);
      await pumpEventQueue();

      sink.success(true);
      await pumpEventQueue();
      expect(protection.captured, isTrue);

      sink.success(false);
      await pumpEventQueue();
      expect(seen, [true, false]);
      expect(protection.captured, isFalse);
      await watching.cancel();
    });
  });
}
