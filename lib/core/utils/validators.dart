// Single source of truth for all user-input validation rules.
// Every screen that validates user input MUST use these — never inline regex.

import 'package:ilnd_app/l10n/app_localizations.dart';

class Validators {
  Validators._();

  // RFC-5321 compatible pattern. Allows:
  //   - standard local parts: letters, digits, . _ % + -
  //   - subdomains:  user@mail.google.com
  //   - ccTLDs:      user@company.co.uk
  //   - minimum TLD: 2 characters
  static final _emailRe = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  /// Returns a localized error string, or null if the value is valid.
  static String? email(String value, AppLocalizations l10n) {
    final v = value.trim();
    if (v.isEmpty) return l10n.validatorEmailRequired;
    if (!_emailRe.hasMatch(v)) return l10n.validatorEmailInvalid;
    return null;
  }

  static String? password(String value, AppLocalizations l10n) {
    if (value.isEmpty) return l10n.validatorPasswordRequired;
    if (value.length < 6) return l10n.validatorPasswordTooShort;
    return null;
  }

  static String? passwordConfirm(
    String password,
    String confirm,
    AppLocalizations l10n,
  ) {
    if (confirm.isEmpty) return l10n.validatorPasswordConfirmRequired;
    if (password != confirm) return l10n.validatorPasswordMismatch;
    return null;
  }

  static String? name(String value, AppLocalizations l10n) {
    final v = value.trim();
    if (v.isEmpty) return l10n.validatorNameRequired;
    if (v.length < 2) return l10n.validatorNameTooShort;
    return null;
  }
}
