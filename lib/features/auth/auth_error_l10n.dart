import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Maps locale-independent [AuthErrorCode]s to user-language messages.
/// Lives in the UI layer on purpose — the provider must stay context-free.
extension AuthErrorCodeL10n on AuthErrorCode {
  String localized(AppLocalizations l10n) => switch (this) {
    AuthErrorCode.invalidCredentials => l10n.authErrorInvalidCredentials,
    AuthErrorCode.emailInUse => l10n.authErrorEmailInUse,
    AuthErrorCode.weakPassword => l10n.authErrorWeakPassword,
    AuthErrorCode.userNotFound => l10n.authErrorUserNotFound,
    AuthErrorCode.network => l10n.authErrorNetwork,
    AuthErrorCode.invalidEmail => l10n.authErrorInvalidEmail,
    AuthErrorCode.generic => l10n.authErrorGeneric,
    AuthErrorCode.confirmEmail => l10n.authErrorConfirmEmail,
    AuthErrorCode.signupFailed => l10n.authErrorSignupFailed,
    AuthErrorCode.signOutFailed => l10n.authErrorSignOutFailed,
    AuthErrorCode.googleFailed => l10n.authErrorGoogleFailed,
    AuthErrorCode.appleFailed => l10n.authErrorAppleFailed,
    AuthErrorCode.resetFailed => l10n.authErrorResetFailed,
    AuthErrorCode.deleteUnavailable => l10n.authErrorDeleteUnavailable,
    AuthErrorCode.deleteFailed => l10n.authErrorDeleteFailed,
  };
}
