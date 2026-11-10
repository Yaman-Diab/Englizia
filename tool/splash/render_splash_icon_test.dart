// Draws the system splash's guide (android/app/src/main/res/drawable*-xxxhdpi/
// splash_icon.png) from the app's own Mascot, as the splash page's first frame
// shows it: 112dp (the 140dp guide at the intro's .8) in Android 12's 240dp
// icon box. Run after the guide changes:
//   flutter test tool/splash/render_splash_icon_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// xxxhdpi: 4 pixels a dp.
const _scale = 4.0;
const _box = 240.0;
const _guide = 140.0 * .8;

/// The guide stands 2dp above the circle's middle (splash page), at .8.
const _rise = 2.0 * .8;

void main() {
  for (final (brightness, folder) in [
    (Brightness.light, 'drawable-xxxhdpi'),
    (Brightness.dark, 'drawable-night-xxxhdpi'),
  ]) {
    testWidgets('splash icon, ${brightness.name}', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: brightness),
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox.square(
                dimension: _box,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -_rise),
                    child: const Mascot(
                      size: _guide,
                      animate: false,
                      sparkles: false,
                      shadow: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: _scale);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      final file = File('android/app/src/main/res/$folder/splash_icon.png');
      await tester.runAsync(() async {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!);
      });
    });
  }
}
