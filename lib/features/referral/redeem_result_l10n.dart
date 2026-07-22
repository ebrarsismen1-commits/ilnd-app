import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// [RedeemResult]'ı kullanıcı diline çevirir. UI katmanında yaşar — repository
/// context-free kalmalı (Sert Kural #1). `success` için mesaj burada yok:
/// başarı akışı ayrı (success toast + pop) ele alınır.
extension RedeemResultL10n on RedeemResult {
  String localizedError(AppLocalizations l10n) => switch (this) {
    RedeemResult.success => l10n.redeemCodeSuccess,
    RedeemResult.selfReferral => l10n.redeemCodeSelfReferral,
    RedeemResult.alreadyRedeemed => l10n.redeemCodeAlreadyUsed,
    RedeemResult.invalidCode => l10n.redeemCodeInvalid,
    RedeemResult.notReady => l10n.redeemCodeNotReady,
    RedeemResult.failed => l10n.redeemCodeNetworkError,
  };
}
