import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/concept_stations.dart';
import 'package:englizia/features/lessons/presentation/concepts/cubit/concept_session_cubit.dart';
import 'package:englizia/features/lessons/presentation/concepts/cubit/concepts_cubit.dart';
import 'package:englizia/features/lessons/presentation/concepts/pages/concept_session_page.dart';
import 'package:englizia/features/lessons/presentation/concepts/pages/concepts_page.dart';
import 'package:englizia/features/lessons/presentation/concepts/widgets/concept_parts.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/feedback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

import '../../../helpers/fake_concept_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 1);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeConceptRepository concepts;
  late FakeClipPlayer player;

  setUp(() {
    concepts = FakeConceptRepository(bank: mockConcepts());
    player = FakeClipPlayer();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(_settled);
    await tester.pump(_settled);
  }

  Finder said(String text) => find.text(text);

  group('the list', () {
    ConceptsCubit cubit() {
      final subject = ConceptsCubit(concepts);
      addTearDown(subject.close);
      return subject;
    }

    test(
      'kept ones show; with nothing kept and no connection, it says so',
      () async {
        final subject = cubit();
        await subject.start();
        expect(subject.state.load, LoadStatus.ready);

        concepts
          ..bank = null
          ..failure = const NetworkFailure();
        final offline = cubit();
        await offline.start();
        expect(offline.state.load, LoadStatus.failure);
      },
    );

    test('a concept mastered in the session leaves in view', () async {
      final subject = cubit();
      await subject.start();
      final mastered = subject.state.bank!.due[1];
      concepts.bank = concepts.bank!.copyWith(
        due: [...concepts.bank!.due.where((c) => c != mastered)],
      );

      await subject.returned(mastered: {mastered.id});

      expect(subject.state.leaving, [mastered]);
      subject.left();
      expect(subject.state.leaving, isEmpty);
    });

    Future<ConceptsCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      Future<Set<String>> Function()? onStart,
    }) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: ConceptsPage(
            onBack: () {},
            onStart: onStart ?? () async => const {},
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await settle(tester);
      return subject;
    }

    testWidgets('today\'s concepts, how often they came, and their stations', (
      tester,
    ) async {
      await pump(tester);

      expect(said('concept_how'.tr()), findsOneWidget);
      expect(said(mockConcepts().due.first.arabic), findsOneWidget);
      expect(said('concept_repeats'.plural(3)), findsOneWidget);
      expect(find.byType(StationDots), findsNWidgets(3));
      expect(said('concept_mastered'.plural(7)), findsOneWidget);
      expect(said('concept_start'.tr(namedArgs: {'n': '3'})), findsOneWidget);
    });

    testWidgets('«لاحقًا» opens with when each comes back', (tester) async {
      await pump(tester);
      final later = mockConcepts().later.first.arabic;
      expect(said(later), findsNothing);

      await tester.tap(said('concept_later'.tr(namedArgs: {'n': '2'})));
      await settle(tester);

      expect(said(later), findsOneWidget);
    });

    testWidgets('the mastered ones open in a sheet', (tester) async {
      await pump(tester);

      await tester.tap(said('concept_mastered'.plural(7)));
      await settle(tester);

      expect(said(mockConcepts().mastered.first.arabic), findsOneWidget);
    });

    testWidgets('nothing due: the guide asleep, and no way to start', (
      tester,
    ) async {
      concepts.bank = concepts.bank!.copyWith(due: []);
      await pump(tester);

      expect(said('concept_none_today'.tr()), findsOneWidget);
      expect(
        find.textContaining('concept_start'.tr(namedArgs: {'n': ''})),
        findsNothing,
      );
    });

    testWidgets('no mistakes yet: how the bank works', (tester) async {
      concepts.bank = const ConceptBank();
      await pump(tester);

      expect(said('concept_none_yet'.tr()), findsOneWidget);
      expect(said('concept_later'.tr(namedArgs: {'n': '0'})), findsNothing);
    });

    testWidgets('back from a session, a mastered one leaves', (tester) async {
      final mastered = mockConcepts().due[1];
      await pump(
        tester,
        onStart: () async {
          concepts.bank = concepts.bank!.copyWith(
            due: [...concepts.bank!.due.where((c) => c.id != mastered.id)],
          );
          return {mastered.id};
        },
      );

      await tester.tap(said('concept_start'.tr(namedArgs: {'n': '3'})));
      await tester.pump();
      await tester.pump();
      expect(said(mastered.arabic), findsOneWidget);

      await settle(tester);
      expect(said(mastered.arabic), findsNothing);
    });

    testLayouts('it fits', (tester, layout) async {
      for (final bank in [
        mockConcepts(),
        mockConcepts().copyWith(due: []),
        const ConceptBank(),
      ]) {
        concepts.bank = bank;
        final subject = await pump(
          tester,
          locale: layout.locale,
          size: layout.size,
          themeMode: layout.themeMode,
        );
        subject.toggleLater();
        await settle(tester);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('a session', () {
    ConceptSessionCubit cubit() {
      final subject = ConceptSessionCubit(concepts, player)..start();
      addTearDown(subject.close);
      return subject;
    }

    Future<void> answer(
      ConceptSessionCubit subject,
      ExerciseDraft draft,
    ) async {
      subject
        ..tryQuestion()
        ..updateDraft(draft);
      await subject.check();
      await subject.answered();
    }

    const plays = TextDraft('plays');
    const doesnt = ChoiceDraft('o2');
    const rained = SlotsDraft([WordChip(id: 'x', text: 'rained')]);

    test('card, question, result, and on to the next', () async {
      final subject = cubit();
      expect(subject.state.stage, ConceptStage.card);
      expect(subject.state.concepts, hasLength(3));

      subject.tryQuestion();
      expect(subject.state.stage, ConceptStage.question);
      expect(subject.state.canCheck, isFalse);

      subject.updateDraft(plays);
      await subject.check();
      expect(subject.state.evaluation?.correct, isTrue);

      await subject.answered();
      expect(subject.state.stage, ConceptStage.result);
      expect(subject.state.outcome?.kind, OutcomeKind.step);
      expect(concepts.answers.single, ('c_present_s', true));

      subject.nextConcept();
      expect(subject.state.index, 1);
      expect(subject.state.stage, ConceptStage.card);
      expect(subject.state.draft, isNull);
    });

    test('the fifth station masters it; a wrong one goes back', () async {
      final subject = cubit();
      await answer(subject, plays);
      subject.nextConcept();
      await answer(subject, doesnt);
      expect(subject.state.outcome?.kind, OutcomeKind.mastered);
      subject.nextConcept();
      await answer(subject, rained);
      expect(subject.state.outcome?.kind, OutcomeKind.again);
      expect(subject.state.outcome?.to, 1);
      subject.nextConcept();

      expect(subject.state.stage, ConceptStage.done);
      expect(subject.state.count(OutcomeKind.mastered), 1);
      expect(subject.mastered, {'c_doesnt'});
    });

    test(
      'a report goes with the concept, and leaving sends what waits',
      () async {
        final subject = cubit();
        await subject.report(ProblemReason.alsoRight);
        await subject.close();

        expect(concepts.reports.single, (
          'c_present_s',
          ProblemReason.alsoRight,
        ));
        expect(concepts.sends, 1);
      },
    );

    Future<ConceptSessionCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      ValueChanged<Set<String>>? onExit,
    }) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: ConceptSessionPage(
            onExit: onExit ?? (_) {},
            onExplain: (_) {},
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await settle(tester);
      return subject;
    }

    testWidgets('the card: the concept, where it went wrong, the stations', (
      tester,
    ) async {
      await pump(tester);
      final first = mockConcepts().due.first;

      expect(said(first.arabic), findsOneWidget);
      expect(said(first.why), findsOneWidget);
      expect(said(first.wrongAnswer!), findsOneWidget);
      expect(
        said('concept_station_of'.tr(namedArgs: {'n': '1'})),
        findsOneWidget,
      );
      expect(find.byType(StationTrack), findsOneWidget);
    });

    testWidgets('a station passed earlier says when', (tester) async {
      final subject = await pump(tester);
      await answer(subject, plays);
      subject.nextConcept();
      await settle(tester);

      expect(
        find.textContaining(
          'concept_right_before'.tr(namedArgs: {'days': ''}).trim(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the question: its chip, its body, «تحقق» then the feedback', (
      tester,
    ) async {
      final subject = await pump(tester);

      await tester.tap(said('concept_try'.tr()));
      await settle(tester);
      expect(find.byType(ConceptChip), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'play');
      await settle(tester);
      await tester.tap(said('lesson_check'.tr()));
      await settle(tester);
      expect(find.byType(FeedbackSheet), findsOneWidget);

      await tester.tap(said('lesson_next'.tr()));
      await settle(tester);
      expect(subject.state.stage, ConceptStage.result);
      expect(said('concept_start_over'.tr()), findsOneWidget);
    });

    testWidgets('a station passed, the concept mastered, and the end', (
      tester,
    ) async {
      Set<String>? left;
      final subject = await pump(tester, onExit: (mastered) => left = mastered);

      await answer(subject, plays);
      await settle(tester);
      expect(said('concept_well_done'.tr()), findsOneWidget);
      expect(
        said('concept_next_station'.tr(namedArgs: {'days': daysText(3)})),
        findsOneWidget,
      );

      await tester.tap(said('concept_next'.tr()));
      await settle(tester);
      await answer(subject, doesnt);
      await settle(tester);
      expect(said('concept_mastered_one'.tr()), findsOneWidget);

      subject.nextConcept();
      await answer(subject, rained);
      subject.nextConcept();
      await settle(tester);
      expect(said('concept_done'.plural(3)), findsOneWidget);

      await tester.tap(said('concept_finish'.tr()));
      expect(left, {'c_doesnt'});
    });

    testLayouts('every stage fits', (tester, layout) async {
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);
      subject
        ..tryQuestion()
        ..updateDraft(const TextDraft('play'));
      await subject.check();
      await settle(tester);
      expect(tester.takeException(), isNull);
      await subject.answered();
      await settle(tester);
      expect(tester.takeException(), isNull);
      subject.nextConcept();
      await answer(subject, doesnt);
      await settle(tester);
      expect(tester.takeException(), isNull);
      subject.nextConcept();
      await answer(subject, rained);
      subject.nextConcept();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
