import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/repositories/explore_repository.dart';
import 'package:ilnd_app/core/repositories/plans_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Planın bir günü: notu, okuması ve tek adımı (ADR-0005).
///
/// Gün başına TEK adım bilinçli — üç adımlı gün, günü yarım bırakma
/// olasılığını üçe katlıyordu.
class PlanDayScreen extends ConsumerWidget {
  const PlanDayScreen({
    super.key,
    required this.plan,
    required this.day,
    required this.dayNumber,
  });

  final Plan plan;
  final PlanDay day;

  /// 1 tabanlı gün sırası — kullanıcıya "3. gün" olarak görünür.
  final int dayNumber;

  static String actionLabel(PlanAction action, AppLocalizations l10n) =>
      switch (action) {
        PlanAction.none => '',
        PlanAction.breath => l10n.planActionBreath,
        PlanAction.move => l10n.planActionMove,
        PlanAction.water => l10n.planActionWater,
        PlanAction.journal => l10n.planActionJournal,
      };

  static IconData actionIcon(PlanAction action) => switch (action) {
    PlanAction.none => Icons.circle_outlined,
    PlanAction.breath => Icons.air_rounded,
    PlanAction.move => Icons.self_improvement_rounded,
    PlanAction.water => Icons.water_drop_outlined,
    PlanAction.journal => Icons.edit_note_rounded,
  };

  /// Günün makalesi. Firestore listesi henüz gelmediyse kod-içi [kArticles]
  /// havuzuna düşer — ağ yokken gün boş bir kabuk olarak açılmasın.
  Article? _article(WidgetRef ref) {
    if (day.articleId.isEmpty) return null;
    final fetched = ref.watch(articlesProvider).valueOrNull;
    final source = (fetched == null || fetched.isEmpty) ? kArticles : fetched;
    for (final a in source) {
      if (a.id == day.articleId) return a;
    }
    return null;
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(planProgressRepositoryProvider);
    // Oturum yoksa (köprü beklemede) yazma denenmez; kullanıcı hata değil
    // sadece kapanan bir ekran görür — gün yarın yeniden karşısına çıkar.
    await repo?.markDayDone(plan.id, day.id);
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final article = _article(ref);
    final done =
        ref.watch(planProgressProvider(plan.id)).valueOrNull?.isDone(day.id) ??
        false;

    return Scaffold(
      backgroundColor: p.base,
      appBar: AppBar(
        backgroundColor: p.base,
        elevation: 0,
        foregroundColor: p.text,
        title: Text(
          l10n.planDayLabel(dayNumber),
          style: AppTextStyles.label(fontSize: 11.5, color: p.textMuted),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            32,
          ),
          children: [
            Text(
              day.title,
              style: AppTextStyles.display(fontSize: 28, color: p.text),
            ),
            if (day.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                day.note,
                style: AppTextStyles.body(
                  fontSize: 15,
                  color: p.textMuted,
                ).copyWith(height: 1.6),
              ),
            ],
            if (article != null) ...[
              const SizedBox(height: 28),
              Text(
                l10n.planDayRead,
                style: AppTextStyles.sectionLabel(color: p.textMuted),
              ),
              const SizedBox(height: 10),
              _ArticleRow(article: article.forLocale(l10n.localeName), p: p),
            ],
            if (day.action != PlanAction.none) ...[
              const SizedBox(height: 28),
              Text(
                l10n.planDayAction,
                style: AppTextStyles.sectionLabel(color: p.textMuted),
              ),
              const SizedBox(height: 10),
              _ActionRow(
                icon: actionIcon(day.action),
                label: actionLabel(day.action, l10n),
                p: p,
              ),
            ],
            const SizedBox(height: 32),
            if (done)
              Center(
                child: Text(
                  l10n.planDayDone,
                  style: AppTextStyles.label(fontSize: 11.5, color: p.accent),
                ),
              )
            else
              Pressable(
                onTap: () => _complete(context, ref),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(AppSpacing.radius),
                  ),
                  child: Text(
                    l10n.planDayComplete,
                    style: AppTextStyles.label(
                      fontSize: 11.5,
                      color: p.onAccent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({required this.article, required this.p});

  final Article article;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ArticleDetailScreen(article: article),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.menu_book_rounded, size: 20, color: p.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(fontSize: 13, color: p.text),
                  ),
                  if (article.readTime.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      article.readTime,
                      style: AppTextStyles.body(
                        fontSize: 11.5,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.p});

  final IconData icon;
  final String label;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body(fontSize: 13, color: p.text),
            ),
          ),
        ],
      ),
    );
  }
}
