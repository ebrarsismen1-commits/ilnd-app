import 'package:flutter/material.dart';
import 'package:ilnd_app/core/ilnd/vibe_card_copy.dart';
import 'package:ilnd_app/core/repositories/vibe_card_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Saf görsel widget — 9:16 (Instagram story formatı). Sayı değil, anlatı
/// odaklı: büyük başlık + alt anlatı birincil görsel, küçük istatistik satırı
/// ikincil detay.
class VibeCardWidget extends StatelessWidget {
  const VibeCardWidget({
    super.key,
    required this.data,
    required this.userName,
    required this.p,
  });

  final VibeCardData data;
  final String userName;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final months = l10n.journalMonths.split(',');
    final weekRangeLabel =
        '${data.weekStart.day} ${months[data.weekStart.month - 1]}'
        ' – ${data.weekEnd.day} ${months[data.weekEnd.month - 1]}';
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
              style: AppTextStyles.display(fontSize: 22, color: p.accent),
            ),
            const SizedBox(height: 6),
            Text(
              weekRangeLabel,
              style: AppTextStyles.label(
                fontSize: 11,
                color: p.textMuted,
              ).copyWith(letterSpacing: 0.6),
            ),
            const Spacer(flex: 3),
            Text(
              VibeCardCopy.headline(
                journalCount: data.journalCount,
                streakDays: data.streakDays,
                l10n: l10n,
              ),
              style: AppTextStyles.display(
                fontSize: 32,
                color: p.text,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              VibeCardCopy.subline(
                journalCount: data.journalCount,
                habitCount: data.habitCompletionCount,
                l10n: l10n,
              ),
              style: AppTextStyles.body(
                fontSize: 16,
                color: p.textMuted,
                height: 1.4,
              ),
            ),
            const Spacer(flex: 4),
            Row(
              children: [
                _StatPill(
                  label: l10n.vibeCardStatStreak,
                  value: '${data.streakDays}',
                  p: p,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  label: l10n.vibeCardStatJournal,
                  value: '${data.journalCount}',
                  p: p,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  label: l10n.vibeCardStatHabit,
                  value: '${data.habitCompletionCount}',
                  p: p,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              userName.isEmpty ? 'ilnd.app' : '$userName · ilnd.app',
              style: AppTextStyles.label(
                fontSize: 10,
                color: p.textMuted,
              ).copyWith(letterSpacing: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.p});
  final String label;
  final String value;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.mono(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.label(fontSize: 9, color: p.textMuted),
          ),
        ],
      ),
    );
  }
}
