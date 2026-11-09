import 'dart:async';

import 'package:englizia/core/security/protected_video.dart';
import 'package:englizia/core/security/screen_protection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _Protection implements ScreenProtection {
  _Protection({this.captured = false});

  var holds = 0;
  final _changes = StreamController<bool>.broadcast();

  @override
  bool captured;

  void capture(bool on) {
    captured = on;
    _changes.add(on);
  }

  @override
  VoidCallback protect() {
    holds++;
    return () => holds--;
  }

  @override
  Stream<bool> get capturedChanges => _changes.stream;
}

/// The view listens from the zone its first build ran in, the translations'
/// real one, so an event reaches it there before the frame.
Future<void> _deliver(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

void main() {
  setUpAll(initLocalizationForTests);

  const video = Text('the video and its controls');

  Future<int Function()> pump(
    WidgetTester tester,
    _Protection protection,
  ) async {
    var pauses = 0;
    await tester.pumpLocalized(
      Scaffold(
        body: ProtectedVideo(
          protection: protection,
          onCaptured: () => pauses++,
          child: video,
        ),
      ),
    );
    return () => pauses;
  }

  testWidgets('held while it shows, let go once it is gone', (tester) async {
    final protection = _Protection();
    await pump(tester, protection);
    expect(protection.holds, 1);
    expect(find.text('the video and its controls'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(protection.holds, 0);
  });

  testWidgets('a recording hides the video and its controls, and pauses it; '
      'it comes back when the recording stops', (tester) async {
    final protection = _Protection();
    final pauses = await pump(tester, protection);

    protection.capture(true);
    await _deliver(tester);
    expect(find.text('the video and its controls'), findsNothing);
    expect(find.byIcon(Icons.videocam_off_rounded), findsOneWidget);
    expect(pauses(), 1);

    protection.capture(false);
    await _deliver(tester);
    expect(find.text('the video and its controls'), findsOneWidget);
    // Coming back doesn't play it: the learner does.
    expect(pauses(), 1);
  });

  testWidgets('opened while recording: covered and paused at once', (
    tester,
  ) async {
    final protection = _Protection(captured: true);
    final pauses = await pump(tester, protection);
    await tester.pump();

    expect(find.text('the video and its controls'), findsNothing);
    expect(pauses(), 1);
  });

  testLayouts('the cover fits', (tester, layout) async {
    await tester.pumpLocalized(
      Scaffold(
        body: SizedBox(
          height: 180,
          child: ProtectedVideo(
            protection: _Protection(captured: true),
            child: video,
          ),
        ),
      ),
      locale: layout.locale,
      size: layout.size,
      themeMode: layout.themeMode,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
