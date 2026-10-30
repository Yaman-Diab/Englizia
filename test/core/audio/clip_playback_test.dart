import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

class _GatedPlayer extends FakeClipPlayer {
  final gate = Completer<void>();

  @override
  Future<Duration?> load(String url) async {
    await gate.future;
    return super.load(url);
  }
}

void main() {
  testWidgets('plays for the clip\'s length, then says it ended', (
    tester,
  ) async {
    final player = FakeClipPlayer(length: const Duration(seconds: 2));
    final playback = ClipPlayback(player);
    var ended = 0;

    final outcome = await playback.start('clip', onEnd: () => ended++);

    expect(outcome, isA<ClipPlaying>());
    expect((outcome as ClipPlaying).length, const Duration(seconds: 2));
    expect(player.played, 1);

    await tester.pump(const Duration(seconds: 2));

    expect(ended, 1);
    playback.stop();
    expect(player.stopped, 0);
  });

  testWidgets('a slower clip takes longer', (tester) async {
    final player = FakeClipPlayer(length: const Duration(seconds: 3));
    final playback = ClipPlayback(player);
    var ended = 0;

    final outcome = await playback.start(
      'clip',
      speed: .75,
      onEnd: () => ended++,
    );

    expect((outcome as ClipPlaying).length, const Duration(seconds: 4));
    expect(player.lastSpeed, .75);
    await tester.pump(const Duration(seconds: 3));
    expect(ended, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(ended, 1);
  });

  test('a clip that fails to load is unavailable', () async {
    final playback = ClipPlayback(FakeClipPlayer(fails: 1));

    expect(await playback.start('clip', onEnd: () {}), isA<ClipUnavailable>());
  });

  testWidgets('stopping ends it, with no word of an ending', (tester) async {
    final player = FakeClipPlayer();
    final playback = ClipPlayback(player);
    var ended = 0;
    await playback.start('clip', onEnd: () => ended++);

    playback.stop();
    await tester.pump(const Duration(seconds: 10));

    expect(player.stopped, 1);
    expect(ended, 0);
  });

  test('a clip stopped while loading never plays', () async {
    final player = _GatedPlayer();
    final playback = ClipPlayback(player);

    final outcome = playback.start('clip', onEnd: () {});
    playback.stop();
    player.gate.complete();

    expect(await outcome, isA<ClipCancelled>());
    expect(player.played, 0);
  });

  testWidgets('a new clip replaces the one playing', (tester) async {
    final player = FakeClipPlayer();
    final playback = ClipPlayback(player);
    var firstEnded = 0;
    await playback.start('one', onEnd: () => firstEnded++);

    await playback.start('two', onEnd: () {});

    expect(player.stopped, 1);
    expect(player.played, 2);
    await tester.pump(const Duration(seconds: 10));
    expect(firstEnded, 0);
  });
}
