import 'package:englizia/core/session/phone_time_zone.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_timezone');

  void phoneSays(Object? Function() answer) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => answer());
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }

  test('an area and a place is a zone’s name; anything else isn’t', () {
    expect(ianaZone('Asia/Damascus'), 'Asia/Damascus');
    expect(
      ianaZone('America/Argentina/Buenos_Aires'),
      'America/Argentina/Buenos_Aires',
    );
    expect(ianaZone('Etc/GMT-3'), 'Etc/GMT-3');
    expect(ianaZone('UTC'), 'UTC');
    // What the server refuses (docs/api/auth.md).
    expect(ianaZone('GMT+03:00'), isNull);
    expect(ianaZone('UTC+3'), isNull);
    expect(ianaZone(''), isNull);
  });

  test('the phone’s zone, by its name', () async {
    phoneSays(() => 'Asia/Damascus');

    expect(await const PlatformPhoneTimeZone().name(), 'Asia/Damascus');
  });

  test('the phone’s zone, when it comes with its localized name', () async {
    phoneSays(() => {'identifier': 'Europe/Berlin', 'localizedName': null});

    expect(await const PlatformPhoneTimeZone().name(), 'Europe/Berlin');
  });

  test('a zone with no place, or none at all, is no name', () async {
    phoneSays(() => 'GMT+03:00');
    expect(await const PlatformPhoneTimeZone().name(), isNull);

    phoneSays(() => null);
    expect(await const PlatformPhoneTimeZone().name(), isNull);

    phoneSays(() => throw PlatformException(code: 'unavailable'));
    expect(await const PlatformPhoneTimeZone().name(), isNull);
  });

  test('with no plugin behind it (a test, a desktop) it is no name', () async {
    expect(await const PlatformPhoneTimeZone().name(), isNull);
  });
}
