import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/audio/mock_clips.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every audio link in the mock's data.
Set<String> _mockLinks() {
  final links = <String>{};
  void walk(Object? node) {
    switch (node) {
      case final Map<String, Object?> map:
        map.values.forEach(walk);
      case final List<Object?> list:
        list.forEach(walk);
      case final String text
          when text.contains('example.com/') && text.endsWith('.mp3'):
        links.add(text);
    }
  }

  for (final file in Directory('assets/mock').listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.json')) {
      walk(jsonDecode(file.readAsStringSync()));
    }
  }
  return links;
}

void main() {
  test('every clip of the mock has its spoken file, by the generator\'s '
      'rule', () {
    final links = _mockLinks();
    expect(links, isNotEmpty);
    for (final link in links) {
      final asset = MockClips.assetFor(link);
      expect(asset, isNotNull, reason: link);
      expect(File(asset!).existsSync(), isTrue, reason: '$link -> $asset');
    }
  });

  test('a link is named by its host and path', () {
    expect(
      MockClips.assetFor('https://cdn.example.com/talk/jake-0.mp3'),
      'assets/mock/audio/cdn_example_com_talk_jake_0.wav',
    );
  });

  test('a real link is the server\'s: no bundled file', () {
    expect(MockClips.assetFor('https://api.engleazia.com/a/1.mp3'), isNull);
    expect(
      MockClips.assetFor('https://test-streams.mux.dev/x/main.m3u8'),
      isNull,
    );
  });

  test('no spoken file is left over from a link that went', () {
    final used = {for (final link in _mockLinks()) MockClips.assetFor(link)};
    for (final file in Directory(MockClips.folder).listSync()) {
      expect(used, contains(file.path.replaceAll(r'\', '/')));
    }
  });
}
