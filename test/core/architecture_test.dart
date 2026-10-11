import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layer rules from CLAUDE.md, enforced on import lines.
void main() {
  final importLine = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

  Iterable<(String, String)> importsUnder(String dir) sync* {
    final root = Directory(dir);
    if (!root.existsSync()) return;
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final line in file.readAsLinesSync()) {
        final match = importLine.firstMatch(line);
        if (match != null) yield (file.path, match.group(1)!);
      }
    }
  }

  test('core/ imports nothing from app/ or features/', () {
    final violations = [
      for (final (file, uri) in importsUnder('lib/core'))
        if (uri.contains('/app/') ||
            uri.contains('/features/') ||
            uri.startsWith('package:englizia/app') ||
            uri.startsWith('package:englizia/features'))
          '$file → $uri',
    ];
    expect(violations, isEmpty);
  });

  test('domain/ stays pure Dart', () {
    final features = Directory('lib/features');
    if (!features.existsSync()) return;
    final violations = <String>[];
    for (final feature in features.listSync().whereType<Directory>()) {
      final name = feature.uri.pathSegments.where((s) => s.isNotEmpty).last;
      for (final (file, uri) in importsUnder('${feature.path}/domain')) {
        final forbidden =
            uri.startsWith('package:flutter/') ||
            uri.startsWith('package:dio/') ||
            uri.contains('core/network') ||
            (uri.contains('/features/') &&
                uri.contains('/data/') &&
                !uri.contains('/features/$name/'));
        if (forbidden) violations.add('$file → $uri');
      }
    }
    expect(violations, isEmpty);
  });

  test('features never use raw colors', () {
    final features = Directory('lib/features');
    if (!features.existsSync()) return;
    final rawColor = RegExp(r'Color\(0x|Colors\.(?!transparent)');
    final violations = [
      for (final file in features.listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') &&
            rawColor.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(violations, isEmpty);
  });
}
