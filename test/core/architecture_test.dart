import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layer and layout rules from CLAUDE.md, enforced by scanning source files.
void main() {
  final importLine = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

  // Physical left/right APIs that do not flip in RTL. Direction-neutral ones
  // (EdgeInsets.all/symmetric, Alignment.center, BorderRadius.circular) stay allowed.
  final nonDirectional = RegExp(
    r'\bEdgeInsets\.(only|fromLTRB)\('
    r'|\bBorderRadius\.(only|horizontal)\('
    r'|\bAlignment\.(topLeft|topRight|centerLeft|centerRight|bottomLeft|bottomRight)\b'
    r'|\bPositioned\('
    r'|\bTextAlign\.(left|right)\b',
  );

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

  test('lib/ uses directional layout only', () {
    final violations = [
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart'))
          for (final (index, line) in file.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//') &&
                nonDirectional.hasMatch(line))
              '${file.path}:${index + 1}',
    ];
    expect(
      violations,
      isEmpty,
      reason:
          'Use EdgeInsetsDirectional, AlignmentDirectional, '
          'PositionedDirectional, BorderRadiusDirectional, TextAlign.start/end',
    );
  });

  test('the directional-layout scan catches physical left/right APIs', () {
    const physical = [
      'padding: EdgeInsets.only(left: 8)',
      'EdgeInsets.fromLTRB(1, 2, 3, 4)',
      'BorderRadius.only(topLeft: radius)',
      'alignment: Alignment.centerLeft',
      'Positioned(left: 0, child: child)',
      'textAlign: TextAlign.right',
    ];
    const directionalOrNeutral = [
      'EdgeInsetsDirectional.only(start: 8)',
      'EdgeInsets.symmetric(horizontal: 8)',
      'EdgeInsets.all(8)',
      'AlignmentDirectional.centerStart',
      'Alignment.center',
      'BorderRadius.circular(12)',
      'BorderRadius.vertical(top: radius)',
      'PositionedDirectional(start: 0, child: child)',
      'Positioned.fill(child: child)',
      'TextAlign.start',
      'TextDirection.ltr',
    ];
    for (final line in physical) {
      expect(nonDirectional.hasMatch(line), isTrue, reason: line);
    }
    for (final line in directionalOrNeutral) {
      expect(nonDirectional.hasMatch(line), isFalse, reason: line);
    }
  });
}
