import 'dart:convert';
import 'dart:io';

/// A real server response saved under `test/fixtures/api/` (sanitized), as
/// decoded JSON. Tests parse these so a contract change fails a test.
Map<String, Object?> apiFixture(String name) =>
    jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync())
        as Map<String, Object?>;
