import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/sound_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// A WAV file's format and its peak, read from its bytes.
({int channels, int rate, int bits, double seconds, double peakDb}) _wav(
  File file,
) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: file.path);
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE', reason: file.path);
  var at = 12;
  int? channels;
  int? rate;
  int? bits;
  while (at + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(at, at + 4));
    final size = data.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ') {
      channels = data.getUint16(body + 2, Endian.little);
      rate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      var peak = 0;
      for (var i = body; i + 1 < body + size; i += 2) {
        final v = data.getInt16(i, Endian.little).abs();
        if (v > peak) peak = v;
      }
      final frames = size / (channels! * bits! ~/ 8);
      return (
        channels: channels,
        rate: rate!,
        bits: bits,
        seconds: frames / rate,
        peakDb: peak == 0 ? -999 : 20 * math.log(peak / 32768) / math.ln10,
      );
    }
    at = body + size + (size.isOdd ? 1 : 0);
  }
  fail('${file.path} has no data');
}

void main() {
  const voices = {
    AppSound.guideWelcome,
    AppSound.hello,
    AppSound.placementTrial,
  };

  test('every effect has its line in the catalog; the voices have none', () {
    for (final sound in AppSound.values) {
      expect(
        soundCatalog.containsKey(sound),
        !voices.contains(sound),
        reason: '$sound',
      );
    }
  });

  test('every file of the catalog is bundled, and nothing else is', () {
    final listed = {
      for (final spec in soundCatalog.values) ...[spec.asset, ?spec.kidsAsset],
    };
    final onDisk = {
      for (final file in Directory(SoundSpec.folder).listSync(recursive: true))
        if (file is File && file.path.endsWith('.wav'))
          file.path.replaceAll(r'\', '/'),
    };

    expect(onDisk, listed);
    final assets = File('pubspec.yaml').readAsLinesSync().map((l) => l.trim());
    expect(assets, contains('- assets/sounds/'));
    expect(assets, contains('- assets/sounds/kids/'));
  });

  test('every file says where it came from', () {
    final licenses = File('${SoundSpec.folder}/LICENSES.md').readAsStringSync();
    for (final spec in soundCatalog.values) {
      expect(licenses, contains('`${spec.file}`'), reason: spec.file);
      if (spec.kids case final kids?) {
        expect(licenses, contains('`kids/$kids`'), reason: kids);
      }
    }
  });

  test('volumes stay between silence and the file\'s own level', () {
    for (final spec in soundCatalog.values) {
      expect(spec.volume, inInclusiveRange(0, 1), reason: spec.file);
    }
  });

  test('every file plays on both phones: WAV, mono, 16-bit, 44.1 kHz, its '
      'peak at -3 dBFS or under', () {
    for (final file in Directory(SoundSpec.folder).listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.wav')) continue;
      final wav = _wav(file);
      expect(wav.channels, 1, reason: file.path);
      expect(wav.bits, 16, reason: file.path);
      expect(wav.rate, 44100, reason: file.path);
      expect(wav.peakDb, lessThan(-2.8), reason: file.path);
      expect(wav.peakDb, greaterThan(-6), reason: file.path);
    }
  });

  test('each lasts as the brief has it', () {
    // The longest each may last: a sound heard 50 times must stay short.
    const longest = {
      'correct.wav': .5,
      'incorrect.wav': .35,
      'tap.wav': .1,
      'lesson_complete.wav': 2.0,
      'achievement.wav': 3.0,
      'island_unlock.wav': 1.5,
      'daily_goal.wav': 1.2,
      'mic_on.wav': .16,
      'mic_off.wav': .16,
      'save_word.wav': .2,
      'freeze.wav': 1.2,
      'notification.wav': 1.5,
      'xp_tick.wav': .06,
      'card_flip.wav': .2,
    };
    for (final MapEntry(key: name, value: seconds) in longest.entries) {
      final wav = _wav(File('${SoundSpec.folder}/$name'));
      expect(wav.seconds, lessThanOrEqualTo(seconds), reason: name);
    }
    // A lesson's end and an achievement are phrases, not blips.
    expect(
      _wav(File('${SoundSpec.folder}/lesson_complete.wav')).seconds,
      greaterThan(1),
    );
    expect(
      _wav(File('${SoundSpec.folder}/achievement.wav')).seconds,
      greaterThan(2),
    );
  });
}
