import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Paylaşılabilir kartların ortak alt satırı: kimlik + davet kodu rozeti.
/// Her paylaşılan kart aynı zamanda bir davetiyedir — kod boşsa rozet
/// çizilmez, kart kırılmaz.
class CardFooter extends StatelessWidget {
  const CardFooter({
    super.key,
    required this.userName,
    required this.p,
    this.referralCode = '',
  });

  final String userName;
  final AppPalette p;
  final String referralCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            userName.isEmpty ? 'ilnd.app' : '$userName · ilnd.app',
            style: AppTextStyles.label(
              fontSize: 10,
              color: p.textMuted,
            ).copyWith(letterSpacing: 0.4),
          ),
        ),
        if (referralCode.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.border, width: 0.5),
            ),
            child: Text(
              l10n.vibeCardInviteCode(referralCode),
              style: AppTextStyles.mono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ),
      ],
    );
  }
}
