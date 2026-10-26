import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/features/auth/auth_validation.dart';

void main() {
  test('Email validation accepts trimmed addresses and rejects malformed input',
      () {
    expect(AuthValidation.email(' alice+suivi@example.fr '), isNull);
    for (final email in [
      '',
      'alice@',
      '@example.fr',
      'alice example@domain.fr',
      'alice@@domain.fr'
    ]) {
      expect(AuthValidation.email(email), isNotNull);
    }
  });

  test('New passwords respect BCrypt UTF-8 limits without restricting login',
      () {
    expect(AuthValidation.newPassword('A long phrase 123'), isNull);
    expect(AuthValidation.newPassword('short'), isNotNull);
    expect(AuthValidation.newPassword('      '), isNotNull);
    expect(AuthValidation.newPassword(List.filled(36, 'é').join()), isNull);
    expect(AuthValidation.newPassword(List.filled(37, 'é').join()), isNotNull);
    expect(AuthValidation.requiredPassword('old'), isNull);
  });

  test('Confirmation is required and must match exactly', () {
    expect(AuthValidation.confirmPassword('', 'password'), isNotNull);
    expect(AuthValidation.confirmPassword('password ', 'password'), isNotNull);
    expect(AuthValidation.confirmPassword('password', 'password'), isNull);
  });
}
