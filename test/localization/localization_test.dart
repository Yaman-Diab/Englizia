import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Translation files and code stay in sync: same keys, same placeholders,
/// no empty values, every used key defined, every defined key used, and no
/// visible text hardcoded in Dart. A plural key holds its forms (`zero`,
/// `one`, `two`, `few`, `many`, `other`) and always has `other`.
void main() {
  const locales = ['ar', 'en'];
  const pluralForms = {'zero', 'one', 'two', 'few', 'many', 'other'};

  /// Each key's texts: one, or one per plural form.
  Map<String, Map<String, String>> load(String locale) {
    final raw = File('assets/translations/$locale.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    return decoded.map(
      (key, value) => MapEntry(key, switch (value) {
        final String text => {'': text},
        final Map<String, Object?> forms => forms.map(
          (form, text) => MapEntry(form, text! as String),
        ),
        _ => throw FormatException('$locale:$key is neither text nor forms'),
      }),
    );
  }

  final files = {for (final l in locales) l: load(l)};

  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final usedKeys = <String>{
    for (final file in dartFiles)
      for (final match in RegExp(
        r"'([a-z0-9_]+)'\s*\.\s*(?:tr|plural)\(",
      ).allMatches(file.readAsStringSync()))
        match.group(1)!,
  };

  test('every locale has the same keys', () {
    final reference = files['ar']!.keys.toSet();
    for (final locale in locales) {
      expect(files[locale]!.keys.toSet(), reference, reason: locale);
    }
  });

  test('keys are flat snake_case and appear once per file', () {
    for (final locale in locales) {
      final raw = File('assets/translations/$locale.json').readAsStringSync();
      // Top-level keys only: plural forms are indented further.
      final keys = RegExp(
        r'^  "([^"]+)"\s*:',
        multiLine: true,
      ).allMatches(raw).map((m) => m.group(1)!).toList();
      expect(keys.toSet().length, keys.length, reason: '$locale duplicates');
      for (final key in keys) {
        expect(key, matches(RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$')));
      }
    }
  });

  test('no empty values', () {
    for (final locale in locales) {
      files[locale]!.forEach((key, texts) {
        for (final text in texts.values) {
          expect(text.trim(), isNotEmpty, reason: '$locale:$key');
        }
      });
    }
  });

  test('plural keys have valid forms, including other', () {
    for (final locale in locales) {
      files[locale]!.forEach((key, texts) {
        if (texts.containsKey('')) return;
        expect(pluralForms.containsAll(texts.keys), isTrue, reason: key);
        expect(texts.keys, contains('other'), reason: '$locale:$key');
      });
    }
  });

  test('placeholders match across locales', () {
    final arg = RegExp(r'\{(\w+)\}');
    Set<String> argsOf(Map<String, String> texts) => {
      for (final text in texts.values)
        ...arg.allMatches(text).map((m) => m.group(1)!),
    };
    for (final key in files['ar']!.keys) {
      final reference = argsOf(files['ar']![key]!);
      for (final locale in locales) {
        expect(argsOf(files[locale]![key]!), reference, reason: key);
      }
    }
  });

  test('every key used in code is defined', () {
    final missing = usedKeys.difference(files['ar']!.keys.toSet());
    expect(missing, isEmpty);
  });

  test('every defined key is used in code', () {
    final unused = files['ar']!.keys.toSet().difference(usedKeys);
    expect(unused, isEmpty);
  });

  test('no visible text is hardcoded in Dart', () {
    final arabic = RegExp(r'[؀-ۿ]');
    // Text('literal') or a visible argument (tooltip: 'literal'), unless the
    // literal is a key followed by .tr( / .plural(. The literal may sit on the
    // next line, as dart format puts a long one.
    final visibleLiteral = RegExp(
      r'''(?:\bText\(|\b(?:tooltip|hintText|labelText|semanticsLabel|semanticLabel|message|label):)'''
      r'''\s*['"]([^'"]*)['"](\s*\.\s*(?:tr|plural)\()?''',
    );
    // '$days' or '@${domain}' shows a value, not a sentence.
    final interpolation = RegExp(r'\$(?:\w+|\{[^}]*\}?)');
    final letter = RegExp('[A-Za-z]');
    final violations = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.trimLeft().startsWith('//') && arabic.hasMatch(line)) {
          violations.add('${file.path}:${i + 1}');
        }
      }
      for (final match in visibleLiteral.allMatches(source)) {
        final literal = match.group(1)!.replaceAll(interpolation, '');
        if (match.group(2) != null || !letter.hasMatch(literal)) continue;
        final index = source.substring(0, match.start).split('\n').length - 1;
        if (lines[index].trimLeft().startsWith('//')) continue;
        violations.add('${file.path}:${index + 1}');
      }
    }
    expect(violations, isEmpty);
  });
}
