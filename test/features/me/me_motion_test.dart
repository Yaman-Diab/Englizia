import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:englizia/features/me/presentation/me/pages/me_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_track_repository.dart';
import '../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  final today = DateTime(2026, 11, 5, 10);

  /// «أنا» on the day's first view, where every one-shot motion may play.
  Future<void> pumpFirstView(WidgetTester tester) async {
    final subject = MeCubit(
      FakeProfileRepository(mockProfile(now: today), firstView: true),
      FakeTrackRepository(
        tracks: [Ok(mockPublishedTracks())],
        levels: [Ok(mockEmarLevels())],
      ),
      isGuest: () => false,
      now: () => today,
    );
    addTearDown(subject.close);
    await tester.pumpLocalized(
      BlocProvider.value(
        value: subject,
        child: Scaffold(
          body: MePage(
            actions: MeActions(
              onSettings: () {},
              onPrivacy: () {},
              onWhatsApp: (_) {},
              onPractice: () {},
              onCreateAccount: () {},
              onSignOut: () async {},
              onVerifyEmail: () async {},
              onRetest: () {},
              onJoin: (_) {},
            ),
          ),
        ),
      ),
    );
    await subject.start();
    await tester.pump();
    // The counting is over for anything that started with the page. The
    // trailing ticks fire flutter_animate's zero-length start timers, as
    // `settleEntrance` does.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('«أنا»\'s motion waits to be seen', () {
    testWidgets('a number below the fold has not counted yet', (tester) async {
      await pumpFirstView(tester);

      // «64 كلمة محفوظة» sits about 1000dp down, well past a 812dp screen.
      expect(find.text('64'), findsNothing);
      expect(find.text('23'), findsNothing);
    });

    testWidgets('scrolling to it makes it count up to its value', (
      tester,
    ) async {
      await pumpFirstView(tester);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('64'), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
    });

    testWidgets('on a later view that day the numbers are simply there', (
      tester,
    ) async {
      final subject = MeCubit(
        FakeProfileRepository(mockProfile(now: today)),
        FakeTrackRepository(
          tracks: [Ok(mockPublishedTracks())],
          levels: [Ok(mockEmarLevels())],
        ),
        isGuest: () => false,
        now: () => today,
      );
      addTearDown(subject.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: Scaffold(
            body: MePage(
              actions: MeActions(
                onSettings: () {},
                onPrivacy: () {},
                onWhatsApp: (_) {},
                onPractice: () {},
                onCreateAccount: () {},
                onSignOut: () async {},
                onVerifyEmail: () async {},
                onRetest: () {},
                onJoin: (_) {},
              ),
            ),
          ),
        ),
      );
      await subject.start();
      await tester.pump();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pump();

      // No first view, so no counting: the value is there on the first frame.
      expect(find.text('64'), findsOneWidget);
    });
  });
}
