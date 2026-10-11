import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Translation files and code stay in sync: same keys, same placeholders,
/// no empty values, every used key defined, every defined key used, and no
/// visible text hardcoded in Dart.
void main() {
  const locales = ['ar', 'en'];

  Map<String, String> load(String locale) {
    final raw = File('assets/translations/$locale.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    return decoded.map((key, value) => MapEntry(key, value! as String));
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
      final keys = RegExp(
        r'^\s*"([^"]+)"\s*:',
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
      files[locale]!.forEach((key, value) {
        expect(value.trim(), isNotEmpty, reason: '$locale:$key');
      });
    }
  });

  test('placeholders match across locales', () {
    final arg = RegExp(r'\{(\w+)\}');
    Set<String> argsOf(String text) =>
        arg.allMatches(text).map((m) => m.group(1)!).toSet();
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
    // Text('literal') unless the literal is a key followed by .tr( / .plural(
    final textLiteral = RegExp(
      r'''\bText\(\s*['"]([^'"]*)['"](\s*\.\s*(?:tr|plural)\()?''',
    );
    final letter = RegExp('[A-Za-z]');
    final violations = <String>[];
    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        final hardcoded = textLiteral
            .allMatches(line)
            .any((m) => m.group(2) == null && letter.hasMatch(m.group(1)!));
        if (arabic.hasMatch(line) || hardcoded) {
          violations.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(violations, isEmpty);
  });
}
