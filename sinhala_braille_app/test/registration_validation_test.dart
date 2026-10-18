import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_braille_app/utils/registration_validation.dart';

void main() {
  test('accepts plus addressing and long domain endings', () {
    for (final email in [
      'reader+notes@example.com',
      'reader@example.technology',
      'first.last@sub.example.co.uk',
    ]) {
      expect(isValidRegistrationEmail(email), isTrue, reason: email);
    }
  });
  test('rejects malformed email addresses', () {
    for (final email in [
      'a@@example.com',
      'a b@example.com',
      '.a@example.com',
      'a..b@example.com',
      'a@example..com',
      'a@-example.com',
      'a@example.com\n',
      'a@example',
      'a@exa_mple.com',
    ]) {
      expect(isValidRegistrationEmail(email), isFalse, reason: email);
    }
  });
}
