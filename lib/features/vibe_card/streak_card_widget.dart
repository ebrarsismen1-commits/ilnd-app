import 'package:flutter/material.dart';
import 'package:ilnd_app/core/ilnd/streak_copy.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/features/vibe_card/card_footer.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Streak eşik kartı (7+/30+/100+ gün) — 9:16 story formatı. Büyük gün
/// sayısı birincil görsel; başlık "bunu az insan yapar" gururunu taşır.
class StreakCardWidget extends StatelessWidget {
  const StreakCardWidget({
    super.key,
    required this.days,
    required this.userName,
    required this.p,
    this.referralCode = '',
  });

  final int days;
  final String userName;
  final AppPalette p;
  final String referralCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final headline = StreakCopy.milestoneHeadline(days: days, l10n: l10n);

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: p.aura,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ilnd.',
              style: AppTextStyles.display(fontSize: 24, color: p.accent),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$days',
                            style: AppTextStyles.display(
                              fontSize: 44,
                              color: p.text,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('🔥', style: const TextStyle(fontSize: 24)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.streakCardDaysLabel,
                    style: AppTextStyles.label(
                      fontSize: 11.5,
                      color: p.textMuted,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                  if (headline != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      headline,
                      style: AppTextStyles.display(
                        fontSize: 24,
                        color: p.text,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            CardFooter(userName: userName, p: p, referralCode: referralCode),
          ],
        ),
      ),
    );
  }
}
