import 'package:englizia/core/logging/redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('masks bearer tokens, emails and phone numbers in text', () {
    final text = Redactor.redactText(
      'Authorization: Bearer abc.def-123 user user@example.com phone +963900000000',
    );
    expect(text, isNot(contains('abc.def-123')));
    expect(text, isNot(contains('user@example.com')));
    expect(text, isNot(contains('900000000')));
  });

  test('leaves GUIDs and short ids readable', () {
    const id = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
    expect(Redactor.redactText('/lessons/$id?page=12'), '/lessons/$id?page=12');
  });

  test('masks sensitive keys recursively in JSON', () {
    final redacted = Redactor.redactJson({
      'email': 'user@example.com',
      'password': 'secret',
      'profile': {'refreshToken': 'r1', 'name': 'Sara'},
      'items': [
        {'accessToken': 'a1'},
      ],
    });
    expect(redacted, {
      'email': Redactor.mask,
      'password': Redactor.mask,
      'profile': {'refreshToken': Redactor.mask, 'name': 'Sara'},
      'items': [
        {'accessToken': Redactor.mask},
      ],
    });
  });
}
