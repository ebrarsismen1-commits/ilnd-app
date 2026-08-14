import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/daily_trio/daily_trio_provider.dart';
import 'package:ilnd_app/features/daily_trio/movement_pool.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// "Bugünün Üçlüsü" — ILND'nin gün için hazırladığı üç kart:
/// Hareket (havuzdan günlük), Tabak (profile göre tarif), Kafa (mevcut
/// check-in/ritüel durumuna bağ). Retention çekirdeği: sohbet açılmayan
/// günde bile 10 saniyelik değer.
class DailyTrioSection extends ConsumerWidget {
  const DailyTrioSection({super.key, required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final movement = movementForDay(DateTime.now());
    final recipe = ref.watch(trioRecipeProvider)?.forLocale(l10n.localeName);
    final done = ref.watch(trioDoneProvider);
    final mindDone =
        ref.watch(todaysMoodProvider) != null ||
        ref.watch(sleepRitualDoneTonightProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.trioSectionTitle,
          style: AppTextStyles.sectionLabel(color: p.textMuted),
        ),
        const SizedBox(height: 12),
        _TrioCard(
          emoji: movement.emoji,
          title: l10n.trioMoveTitle,
          subtitle: movement.forLocale(l10n.localeName),
          chip: l10n.trioMinutes(movement.minutes),
          done: done.contains('move'),
          onTick: () {
            unawaited(AnalyticsService.logEvent('trio_move_done', {}));
            ref.read(trioDoneProvider.notifier).toggle('move');
          },
          p: p,
        ),
        if (recipe != null) ...[
          const SizedBox(height: 8),
          _TrioCard(
            emoji: '🍳',
            title: l10n.trioPlateTitle,
            subtitle: recipe.title,
            chip: recipe.readTime,
            done: done.contains('plate'),
            onTick: () {
              unawaited(AnalyticsService.logEvent('trio_plate_done', {}));
              ref.read(trioDoneProvider.notifier).toggle('plate');
            },
            onTap: () {
              unawaited(AnalyticsService.logEvent('trio_recipe_opened', {}));
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ArticleDetailScreen(article: recipe),
                ),
              );
            },
            p: p,
          ),
        ],
        const SizedBox(height: 8),
        _TrioCard(
          emoji: '🌙',
          title: l10n.trioMindTitle,
          subtitle: mindDone ? l10n.trioMindDone : l10n.trioMindPending,
          done: mindDone,
          // Kafa'nın tiki mood/ritüelden türetilir — elle işaretlenmez;
          // dokunuş sohbete götürür (check-in oradan da yapılabilir).
          onTap: mindDone ? null : () => context.push(routeChat),
          p: p,
        ),
      ],
    );
  }
}

class _TrioCard extends StatelessWidget {
  const _TrioCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.chip,
    required this.done,
    this.onTick,
    this.onTap,
    required this.p,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String? chip;
  final bool done;
  final VoidCallback? onTick;
  final VoidCallback? onTap;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.heading(fontSize: 13, color: p.text),
                    ),
                    if (chip != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.base,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          chip!,
                          style: AppTextStyles.label(
                            fontSize: 10,
                            color: p.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: p.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (onTick != null)
            Semantics(
              label: l10n.trioMarkDone,
              button: true,
              child: Pressable(
                onTap: onTick,
                child: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 26,
                  color: done ? p.accent : p.textMuted,
                ),
              ),
            )
          else
            Icon(
              done ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              size: done ? 26 : 20,
              color: done ? p.accent : p.textMuted,
            ),
        ],
      ),
    );

    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}
