import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const json = <String, Object?>{
    'int': 3,
    'intString': '4',
    'double': 2.5,
    'boolNum': 1,
    'boolString': 'true',
    'blank': '   ',
    'name': 'Sara',
    'map': {'a': 1},
    'list': [1, 2],
  };

  test('reads scalars defensively', () {
    expect(json.readInt('int'), 3);
    expect(json.readInt('intString'), 4);
    expect(json.readInt('double'), 2);
    expect(json.readDouble('int'), 3.0);
    expect(json.readBool('boolNum'), isTrue);
    expect(json.readBool('boolString'), isTrue);
    expect(json.readString('name'), 'Sara');
  });

  test('degrades to null on missing, blank or mistyped fields', () {
    expect(json.readInt('missing'), isNull);
    expect(json.readInt('name'), isNull);
    expect(json.readString('blank'), isNull);
    expect(json.readMap('list'), isNull);
    expect(json.readList('map'), isNull);
  });

  test('readText reads bilingual text, null when absent', () {
    const data = <String, Object?>{
      'both': {'ar': 'مرحبًا', 'en': 'Hello'},
      'arOnly': {'ar': 'مرحبًا'},
      'plain': 'Hello',
    };
    expect(
      data.readText('both'),
      const LocalizedText(ar: 'مرحبًا', en: 'Hello'),
    );
    expect(data.readText('arOnly'), const LocalizedText(ar: 'مرحبًا'));
    expect(data.readText('plain'), isNull);
    expect(data.readText('missing'), isNull);
  });

  test('firstOf returns the first present candidate', () {
    expect(json.firstOf(['missing', 'name'], json.readString), 'Sara');
    expect(json.firstOf(['missing', 'other'], json.readString), isNull);
  });

  test('asJsonMap rejects non-objects', () {
    expect(asJsonMap({'a': 1}), {'a': 1});
    expect(() => asJsonMap([1]), throwsFormatException);
  });
}
