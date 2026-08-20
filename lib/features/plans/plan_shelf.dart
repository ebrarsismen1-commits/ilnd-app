import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/repositories/plans_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/plans/plan_detail_screen.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Keşfet'teki plan rafı (ADR-0005) — hareket rafının kardeşi.
///
/// Yayınlanabilir plan yoksa raf HİÇ çizilmez; çağıran taraf listeyi boş
/// bulduğunda bu widget'ı hiç kurmaz (boş raf = olmayan özelliğin sözü).
/// Devam eden plan varsa listenin başına alınır: kullanıcı yarım bıraktığı
/// şeyi aramak zorunda kalmaz.
class PlanShelf extends ConsumerWidget {
  const PlanShelf({super.key, required this.plans, required this.p});

  final List<Plan> plans;
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeId = ref.watch(activePlanIdProvider).valueOrNull;
    final ordered = [...plans]
      ..sort((a, b) {
        if (a.id == activeId) return -1;
        if (b.id == activeId) return 1;
        return a.order.compareTo(b.order);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Text(
            l10n.planShelfLabel,
            style: AppTextStyles.label(fontSize: 11.5, color: p.accent),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            itemCount: ordered.length,
            separatorBuilder: (ctx0, i0) => const SizedBox(width: 12),
            itemBuilder: (context, i) => Entrance(
              index: i,
              child: PlanCard(plan: ordered[i], p: p, l10n: l10n),
            ),
          ),
        ),
      ],
    );
  }
}

class PlanCard extends ConsumerWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.p,
    required this.l10n,
  });

  final Plan plan;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localized = plan.forLocale(l10n.localeName);
    final progress =
        ref.watch(planProgressProvider(plan.id)).valueOrNull ??
        const PlanProgress();
    final done = progress.doneCountIn(localized);

    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlanDetailScreen(plan: plan)),
      ),
      child: SizedBox(
        // Genişlik viewport'a göre kırpılır: dar ekranda kart taşmasın
        // (Sert Kural #14'ün öğrettiği esneklik).
        width: (MediaQuery.sizeOf(context).width * 0.62).clamp(200.0, 260.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(imageUrl: localized.coverUrl, palette: 3),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              done > 0
                                  ? l10n.planProgress(
                                      done,
                                      localized.lengthDays,
                                    )
                                  : l10n.planDayCount(localized.lengthDays),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (localized.premium)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: p.accent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.planPremiumBadge,
                                style: AppTextStyles.label(
                                  fontSize: 10,
                                  color: p.onAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localized.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 13,
                color: p.text,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
