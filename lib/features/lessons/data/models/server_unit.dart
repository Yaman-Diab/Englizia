import 'package:englizia/core/network/json_reader.dart';

/// The level's map as the server sends it (`LevelMapDto`, docs/api/home.md),
/// put in the shapes the app's readers take: a unit's screen here, and home
/// from the same pieces.

/// The server's lesson types, by the names the app's reader knows.
const _kinds = {
  'grammar_video': 'grammarVideo',
  'interactive_video': 'interactiveVideo',
  'interactive_text': 'interactiveText',
  'vocabulary': 'vocabulary',
  'conversation': 'conversation',
};

/// The map's units, in order.
List<Map<String, Object?>> mapUnits(Map<String, Object?> map) => [
  for (final unit in map.readList('units') ?? const <Object?>[])
    if (unit is Map) unit.cast<String, Object?>(),
];

/// One of a unit's `lessons[]`, as a unit's screen and home read it.
Map<String, Object?> lessonFromMap(Map<String, Object?> lesson) => {
  'id': lesson.readString('id'),
  'kind': _kinds[lesson.readString('type')] ?? lesson.readString('type'),
  // The Arabic title, in both app languages (docs/STATUS.md D-124).
  'title': lesson.readString('titleAr'),
  'minutes': ?lesson.readInt('minutes'),
  'page': ?lesson.readMap('bookPages')?.readInt('from'),
  'done': lesson.readString('state') == 'completed',
};

/// A unit's lessons in their order, and its test last when it has one
/// published: the lighthouse, which opens the test (B-33b). With [test]
/// false, its lessons alone.
List<Map<String, Object?>> lessonsFromMap(
  Map<String, Object?> unit, {
  bool test = true,
}) => [
  for (final lesson in unit.readList('lessons') ?? const <Object?>[])
    if (lesson is Map) lessonFromMap(lesson.cast()),
  if (test)
    if (unit.readMap('test') case final test?)
      if (test.readString('id') case final id?)
        {
          'id': id,
          'kind': 'unitReview',
          // Shown by its kind's name: a test has no title of its own.
          'title': '',
          'done': test.readString('state') == 'passed',
        },
];

/// A level as it is named on the screen: its CEFR code when it has one, and
/// its name without that code said twice ("A1 المبتدئ" beside "A1").
({String label, String name}) levelNames(Map<String, Object?>? level) {
  final name = level?.readString('nameAr') ?? '';
  final label = switch (level?.readString('cefrCode')) {
    'pre_a1' => 'Pre-A1',
    final String code => code.toUpperCase(),
    null => name,
  };
  return (
    label: label,
    name: name.startsWith('$label ') ? name.substring(label.length + 1) : name,
  );
}

/// What comes before [index] and keeps it closed, in a track that opens in
/// order; null for an open unit, or the first.
Map<String, Object?>? _link(List<Map<String, Object?>> units, int index) =>
    index < 0 || index >= units.length
    ? null
    : {
        'id': units[index].readString('id'),
        'number': index + 1,
        'title': units[index].readString('titleAr'),
      };

/// A locked unit names the one before it: «تُفتح بعد الوحدة 3».
Map<String, Object?>? lockedByFromMap(
  List<Map<String, Object?>> units,
  int index,
) => units[index].readString('state') == 'locked'
    ? _link(units, index - 1)
    : null;

/// The unit [unitId] of [map] as a unit's screen reads it, or null when the
/// level has no such unit.
Map<String, Object?>? unitFromMap(Map<String, Object?> map, String unitId) {
  final units = mapUnits(map);
  final index = units.indexWhere((unit) => unit.readString('id') == unitId);
  if (index < 0) return null;
  final unit = units[index];
  return {
    'id': unitId,
    'number': index + 1,
    'title': unit.readString('titleAr'),
    'levelLabel': levelNames(map.readMap('level')).label,
    'cover': ?unit.readString('coverUrl'),
    'kidsMode': map.readBool('kidsMode') ?? false,
    'ordered': map.readString('unlockMode') != 'all_open',
    'goals': [
      for (final goal in unit.readList('objectives') ?? const <Object?>[])
        if (goal is Map) ?goal.cast<String, Object?>().readString('ar'),
    ],
    'concepts': [
      for (final concept in unit.readList('concepts') ?? const <Object?>[])
        if (concept is Map)
          {'name': concept.cast<String, Object?>().readString('nameAr')},
    ],
    'bookPages': ?unit.readMap('bookPages'),
    'lockedBy': ?lockedByFromMap(units, index),
    'next': ?_link(units, index + 1),
    'lessons': lessonsFromMap(unit),
  };
}
