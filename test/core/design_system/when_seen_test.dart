import 'package:englizia/core/design_system/motion/when_seen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget page({required List<Widget> before, required Widget probe}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 600)),
          child: SingleChildScrollView(
            child: Column(children: [...before, probe]),
          ),
        ),
      );

  Widget marker() => WhenSeen(
    builder: (context, seen) =>
        SizedBox(height: 100, child: Text(seen ? 'seen' : 'waiting')),
  );

  testWidgets('a child already in sight is seen', (tester) async {
    await tester.pumpWidget(page(before: const [], probe: marker()));
    await tester.pump();

    expect(find.text('seen'), findsOneWidget);
  });

  testWidgets('a child below the fold waits, then is seen on scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(before: const [SizedBox(height: 1200)], probe: marker()),
    );
    await tester.pump();

    expect(find.text('waiting'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pump();

    expect(find.text('seen'), findsOneWidget);
  });

  testWidgets('once seen it stays seen, scrolled away again', (tester) async {
    await tester.pumpWidget(
      page(before: const [SizedBox(height: 1200)], probe: marker()),
    );
    await tester.pump();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pump();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 800));
    await tester.pump();

    expect(find.text('seen'), findsOneWidget);
  });

  testWidgets('a part of the way up is not enough', (tester) async {
    await tester.pumpWidget(
      page(before: const [SizedBox(height: 1200)], probe: marker()),
    );
    await tester.pump();
    // 620 of the 1200 above it: 20px of its 100 shows, under the third asked.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -620),
    );
    await tester.pump();

    expect(find.text('waiting'), findsOneWidget);
  });

  testWidgets('outside a scroll view it is seen at once', (tester) async {
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: marker()),
    );
    await tester.pump();

    expect(find.text('seen'), findsOneWidget);
  });
}
