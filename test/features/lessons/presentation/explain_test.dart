import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/data/models/explanation_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/explanation.dart';
import 'package:englizia/features/lessons/domain/repositories/explain_repository.dart';
import 'package:englizia/features/lessons/presentation/explain/cubit/explain_cubit.dart';
import 'package:englizia/features/lessons/presentation/explain/widgets/explain_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

ExplainReady _ready({bool fresh = true}) {
  final outcome =
      ExplainModel(
            asJsonMap(
              ApiClient.unwrap(
                jsonDecode(
                  File(
                    'test/fixtures/api/explanation_ok.json',
                  ).readAsStringSync(),
                ),
              ),
            ),
          ).toEntity()
          as ExplainReady;
  return ExplainReady(outcome.explanation, left: outcome.left, fresh: fresh);
}

const _request = ExplainRequest(
  questionId: 'Q1',
  draft: ChoiceDraft('o1'),
  lessonExplanation: 'مع he/she/it نضيف s للفعل في المضارع البسيط.',
);

class _Explain implements ExplainRepository {
  /// What each ask answers, in turn; the last one stays.
  List<Result<ExplainOutcome>> answers = [Ok(_ready())];

  /// Holds the answer back until completed, to see the waiting.
  Completer<void>? hold;
  var asked = 0;
  final rated = <bool>[];

  @override
  Future<Result<ExplainOutcome>> explain(ExplainRequest request) async {
    await hold?.future;
    return answers[(asked++).clamp(0, answers.length - 1)];
  }

  @override
  Future<void> rate(String explanationId, {required bool helpful}) async =>
      rated.add(helpful);
}

void main() {
  setUpAll(initLocalizationForTests);

  late _Explain explain;
  late FakeClipPlayer player;

  setUp(() {
    explain = _Explain();
    player = FakeClipPlayer(length: const Duration(milliseconds: 500));
  });

  ExplainCubit cubit() => ExplainCubit(explain, player, request: _request);

  group('the cubit', () {
    test('the explanation, and what is left today', () async {
      final subject = cubit();
      addTearDown(subject.close);

      await subject.start();

      expect(subject.state.status, ExplainStatus.ready);
      expect(subject.state.left, 4);
      expect(subject.state.fresh, isTrue);
    });

    test('a failure can be asked again; none left is said', () async {
      explain.answers = [const Err(NetworkFailure()), Ok(_ready())];
      final subject = cubit();
      addTearDown(subject.close);

      await subject.start();
      expect(subject.state.status, ExplainStatus.failed);
      await subject.retry();
      expect(subject.state.status, ExplainStatus.ready);

      explain.answers = [const Ok(ExplainQuotaOut())];
      explain.asked = 0;
      final out = cubit();
      addTearDown(out.close);
      await out.start();
      expect(out.state.status, ExplainStatus.quotaOut);
    });

    test('the thumbs count once, and the example plays', () async {
      final subject = cubit();
      addTearDown(subject.close);
      await subject.start();

      subject
        ..rate(helpful: true)
        ..rate(helpful: false);
      await subject.playExample();

      expect(explain.rated, [true]);
      expect(subject.state.helpful, isTrue);
      expect(player.loaded, [subject.state.explanation!.exampleAudioUrl]);
    });
  });

  group('the sheet', () {
    Future<void> open(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      await tester.pumpLocalized(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showExplainSheet(context, cubit: cubit),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('it writes, then explains this mistake', (tester) async {
      explain.hold = Completer();
      await open(tester);

      expect(find.text('explain_title'.tr()), findsOneWidget);
      expect(find.text('explain_writing'.tr()), findsOneWidget);

      explain.hold!.complete();
      await settle(tester);

      expect(find.text('explain_yours'.tr()), findsOneWidget);
      expect(find.text('go'), findsOneWidget);
      expect(find.text('goes'), findsOneWidget);
      expect(find.text('explain_why'.tr()), findsOneWidget);
      expect(
        find.text('My brother plays football on Fridays.'),
        findsOneWidget,
      );
      expect(
        find.text('explain_left'.tr(namedArgs: {'count': '4'})),
        findsOneWidget,
      );
    });

    testWidgets('the thumbs, then thanks', (tester) async {
      await open(tester);
      await settle(tester);

      await tester.tap(find.byTooltip('explain_helped_yes'.tr()));
      await tester.pump();

      expect(find.text('explain_thanks'.tr()), findsOneWidget);
      expect(find.byTooltip('explain_helped_no'.tr()), findsNothing);
      expect(explain.rated, [true]);
    });

    testWidgets('it can\'t explain: the lesson\'s own, and a retry', (
      tester,
    ) async {
      explain.answers = [const Err(NetworkFailure()), Ok(_ready())];
      await open(tester);
      await settle(tester);

      expect(find.text('explain_failed'.tr()), findsOneWidget);
      expect(find.text(_request.lessonExplanation!), findsOneWidget);
      expect(find.textContaining('explain_left'.tr()), findsNothing);

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(find.text('explain_why'.tr()), findsOneWidget);
    });

    testWidgets('none left today: said, with the lesson\'s own', (
      tester,
    ) async {
      explain.answers = [const Ok(ExplainQuotaOut())];
      await open(tester);
      await settle(tester);

      expect(find.text('explain_quota_out'.tr()), findsOneWidget);
      expect(find.text('explain_lesson'.tr()), findsOneWidget);
      expect(find.text('common_retry'.tr()), findsNothing);
    });

    testWidgets('the cross closes it', (tester) async {
      await open(tester);
      await settle(tester);

      await tester.tap(find.byTooltip('explain_close'.tr()));
      await settle(tester);

      expect(find.text('explain_title'.tr()), findsNothing);
    });

    testLayouts('every state fits', (tester, layout) async {
      for (final answer in <Result<ExplainOutcome>>[
        Ok(_ready()),
        Ok(_ready(fresh: false)),
        const Err(NetworkFailure()),
        const Ok(ExplainQuotaOut()),
      ]) {
        explain
          ..answers = [answer]
          ..asked = 0;
        await open(
          tester,
          locale: layout.locale,
          size: layout.size,
          themeMode: layout.themeMode,
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('explain_close'.tr()));
        await settle(tester);
      }
    });
  });
}
