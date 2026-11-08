import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/unit_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/unit_plan_model.dart';
import 'package:englizia/features/lessons/data/repositories/unit_repository_impl.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_unit_repository.dart';

class _Remote implements UnitRemoteDataSource {
  var offline = false;
  var calls = 0;

  @override
  Future<UnitPlanModel> getUnit(String unitId) async {
    calls++;
    if (offline) throw const NetworkException('connectionError');
    final known = UnitFakeDataSource.units.contains(unitId);
    return UnitPlanModel(
      known
          ? mockUnitJson(unitId)
          : {...mockUnitJson(UnitFakeDataSource.farm), 'id': unitId},
    );
  }
}

void main() {
  group('the model', () {
    test('every bundled unit reads', () {
      for (final id in UnitFakeDataSource.units) {
        expect(mockUnit(id).lessons, isNotEmpty, reason: id);
      }
    });

    test('a unit: its goals, grammar, lessons and the next one', () {
      final farm = mockUnit(UnitFakeDataSource.farm);

      expect(farm.number, 3);
      expect(farm.levelLabel, 'A2');
      expect(farm.goals, hasLength(3));
      expect(farm.concepts, ['المضارع البسيط', 'a / an']);
      expect(farm.lessons.map((l) => l.kind), [
        LessonKind.vocabulary,
        LessonKind.interactiveVideo,
        LessonKind.grammarVideo,
        LessonKind.interactiveText,
        LessonKind.conversation,
        LessonKind.unitReview,
      ]);
      expect(farm.lessons[4].scenarioId, 'sc_fragile_box');
      expect(farm.next?.title, 'في السوق');
      expect(farm.lockedBy, isNull);
    });

    test('Emar has its pages; kids, pictures and stars', () {
      final emar = mockUnit(UnitFakeDataSource.emar);
      expect(emar.ordered, isFalse);
      expect(emar.bookPages, (from: 30, to: 41));
      expect(emar.lessons.first.page, 30);

      final kids = mockUnit(UnitFakeDataSource.kids);
      expect(kids.kids, isTrue);
      expect(kids.titleAudioUrl, isNotNull);
      expect(kids.lessons.map((l) => l.stars), [5, 4, 3, 0, 0, 0]);
      expect(kids.lessons.first.imageUrl, endsWith('cow.svg'));
    });

    test('a lesson that can\'t be read is left out; none, no unit', () {
      final unit = const UnitPlanModel({
        'id': 'u',
        'lessons': [
          {'id': 'a', 'kind': 'vocabulary', 'title': 'A'},
          {'kind': 'vocabulary'},
          {'id': 'c', 'kind': 'tomorrow', 'title': 'C', 'stars': 9},
        ],
      }).toEntity();
      expect(unit.lessons.map((l) => l.id), ['a', 'c']);
      expect(unit.lessons.last.kind, LessonKind.other);
      expect(unit.lessons.last.stars, 5);

      expect(
        () => const UnitPlanModel({'id': 'u', 'lessons': []}).toEntity(),
        throwsFormatException,
      );
    });
  });

  group('the plan', () {
    test('the current lesson is the first left; the review waits', () {
      final farm = mockUnit(UnitFakeDataSource.farm);

      expect(farm.current, 3);
      expect(farm.doneCount, 3);
      expect(farm.status(0), UnitLessonStatus.done);
      expect(farm.status(3), UnitLessonStatus.current);
      expect(farm.status(4), UnitLessonStatus.locked);
      expect(farm.status(5), UnitLessonStatus.locked);

      final rest = farm.withPhone(
        (id) => LessonOnPhone(done: id != 'les_mock'),
      );
      expect(rest.current, 5, reason: 'the review, once the rest are done');
      expect(rest.status(5), UnitLessonStatus.current);
      final all = farm.withPhone((_) => const LessonOnPhone(done: true));
      expect(all.complete, isTrue);
      expect(all.current, -1);
    });

    test('Emar opens every lesson; a locked unit, none', () {
      final emar = mockUnit(UnitFakeDataSource.emar);
      expect(emar.current, 2);
      expect(emar.status(3), UnitLessonStatus.open);
      expect(emar.status(5), UnitLessonStatus.locked, reason: 'the review');

      final market = mockUnit(UnitFakeDataSource.market);
      expect(market.locked, isTrue);
      expect(market.current, -1);
      expect(List.generate(market.lessons.length, market.status).toSet(), {
        UnitLessonStatus.locked,
      });
    });

    test('the phone knows where a lesson stopped, and what it kept', () {
      final farm = mockUnit(UnitFakeDataSource.farm).withPhone(
        (id) => id == 'les_it'
            ? const LessonOnPhone(
                kept: true,
                resume: LessonResume(question: 3, share: .4),
              )
            : const LessonOnPhone(),
      );

      expect(farm.lessons[3].resume?.question, 3);
      expect(farm.lessons[3].kept, isTrue);
      expect(farm.lessons[2].kept, isFalse);
    });
  });

  group('the repository', () {
    late _Remote remote;
    late SettingsStorageService settings;
    late UnitRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsStorageService(await SharedPreferences.getInstance());
      remote = _Remote();
      repository = UnitRepositoryImpl(remote, settings: settings);
    });

    test('kept on the phone, so it opens offline', () async {
      expect(repository.keptUnit(UnitFakeDataSource.farm), isNull);
      final online = await repository.getUnit(UnitFakeDataSource.farm);
      expect(online, isA<Ok<UnitPlan>>());

      remote.offline = true;
      final offline = await repository.getUnit(UnitFakeDataSource.farm);
      expect((offline as Ok<UnitPlan>).value.id, UnitFakeDataSource.farm);
      expect(repository.keptUnit(UnitFakeDataSource.farm), isNotNull);

      final never = await repository.getUnit(UnitFakeDataSource.kids);
      expect((never as Err).failure, isA<NetworkFailure>());
    });

    test('only the latest units are kept', () async {
      for (var unit = 0; unit < 8; unit++) {
        await repository.getUnit('u$unit');
      }
      expect(repository.keptUnit('u0'), isNull);
      expect(repository.keptUnit('u7'), isNotNull);
    });

    test('the goals open on the first visit only', () async {
      expect(repository.goalsSeen('u'), isFalse);
      await repository.setGoalsSeen('u');
      await repository.setGoalsSeen('u');
      expect(repository.goalsSeen('u'), isTrue);
      expect(settings.unitsSeen, ['u']);
    });
  });
}
