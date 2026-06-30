import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/utils/validators.dart';
import 'package:ilnd_app/l10n/app_localizations_tr.dart';

void main() {
  final l10n = AppLocalizationsTr();

  group('Validators.email', () {
    test('rejects empty value', () {
      expect(Validators.email('', l10n), l10n.validatorEmailRequired);
    });

    test('rejects value with only whitespace', () {
      expect(Validators.email('   ', l10n), l10n.validatorEmailRequired);
    });

    test('rejects missing @', () {
      expect(
        Validators.email('not-an-email', l10n),
        l10n.validatorEmailInvalid,
      );
    });

    test('rejects missing TLD', () {
      expect(
        Validators.email('user@localhost', l10n),
        l10n.validatorEmailInvalid,
      );
    });

    test('rejects single-character TLD', () {
      expect(
        Validators.email('user@example.c', l10n),
        l10n.validatorEmailInvalid,
      );
    });

    test('accepts a standard address', () {
      expect(Validators.email('user@example.com', l10n), isNull);
    });

    test('accepts a subdomain address', () {
      expect(Validators.email('user@mail.example.com', l10n), isNull);
    });

    test('accepts a multi-part TLD (co.uk)', () {
      expect(Validators.email('user@company.co.uk', l10n), isNull);
    });

    test('accepts leading/trailing whitespace by trimming', () {
      expect(Validators.email('  user@example.com  ', l10n), isNull);
    });
  });

  group('Validators.password', () {
    test('rejects empty value', () {
      expect(Validators.password('', l10n), l10n.validatorPasswordRequired);
    });

    test('rejects fewer than 6 characters', () {
      expect(
        Validators.password('abc12', l10n),
        l10n.validatorPasswordTooShort,
      );
    });

    test('accepts exactly 6 characters', () {
      expect(Validators.password('abc123', l10n), isNull);
    });

    test('accepts more than 6 characters', () {
      expect(Validators.password('a-very-long-password', l10n), isNull);
    });
  });

  group('Validators.passwordConfirm', () {
    test('rejects empty confirmation', () {
      expect(
        Validators.passwordConfirm('abc123', '', l10n),
        l10n.validatorPasswordConfirmRequired,
      );
    });

    test('rejects mismatched passwords', () {
      expect(
        Validators.passwordConfirm('abc123', 'abc124', l10n),
        l10n.validatorPasswordMismatch,
      );
    });

    test('accepts matching passwords', () {
      expect(Validators.passwordConfirm('abc123', 'abc123', l10n), isNull);
    });
  });

  group('Validators.name', () {
    test('rejects empty value', () {
      expect(Validators.name('', l10n), l10n.validatorNameRequired);
    });

    test('rejects whitespace-only value', () {
      expect(Validators.name('  ', l10n), l10n.validatorNameRequired);
    });

    test('rejects single-character name', () {
      expect(Validators.name('A', l10n), l10n.validatorNameTooShort);
    });

    test('accepts a two-character name', () {
      expect(Validators.name('Al', l10n), isNull);
    });

    test('trims whitespace before validating length', () {
      expect(Validators.name('  Al  ', l10n), isNull);
    });
  });
}
