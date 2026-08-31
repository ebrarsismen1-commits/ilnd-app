import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/repositories/plans_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/plans/plan_day_screen.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Bir planın detayı: kapak, tanıtım, gün listesi ve ilerleme (ADR-0005).
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.plan});

  final Plan plan;

  bool _locked(WidgetRef ref) =>
      plan.premium && !ref.read(hasPremiumAccessProvider);

  /// Aynı anda tek plan aktif olabilir (ADR-0005). Başka bir plan
  /// çalışıyorsa kullanıcıya sorulur — sessizce geçmek, ilerlemesini
  /// kaybettiğini sandırır.
  Future<bool> _confirmSwitch(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppPalette p,
  ) async {
    final activeId = ref.read(activePlanIdProvider).valueOrNull;
    if (activeId == null || activeId == plan.id) return true;
    final active = ref.read(activePlanProvider);
    final activeTitle = active?.forLocale(l10n.localeName).title ?? '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Koyu mod iki katmanlı (Sert Kural #7): Material dialog kendi
        // yüzeyini paletten almazsa açık temada kalır.
        backgroundColor: p.surface,
        title: Text(
          l10n.planSwitchTitle,
          style: AppTextStyles.body(fontSize: 15, color: p.text),
        ),
        content: Text(
          l10n.planSwitchBody(activeTitle),
          style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.planSwitchCancel,
              style: AppTextStyles.label(fontSize: 11.5, color: p.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.planSwitchConfirm,
              style: AppTextStyles.label(fontSize: 11.5, color: p.accent),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _openDay(
    BuildContext context,
    WidgetRef ref,
    PlanDay day,
    int dayNumber,
    AppLocalizations l10n,
    AppPalette p,
  ) async {
    // Kilit kontrolü her girişte, tek kapıdan: kart üzerinden de gün
    // satırından da aynı yer (ADR-0005 — ikinci bir premium kontrolü yok).
    if (_locked(ref)) {
      await PaywallScreen.show(
        context,
        reason: l10n.planPaywallReason,
        source: 'plan',
      );
      return;
    }
    if (!context.mounted) return;
    if (!await _confirmSwitch(context, ref, l10n, p)) return;
    if (!context.mounted) return;

    await ref.read(planProgressRepositoryProvider)?.start(plan.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) =>
            PlanDayScreen(plan: plan, day: day, dayNumber: dayNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final localized = plan.forLocale(l10n.localeName);
    final days = localized.days;
    final progress =
        ref.watch(planProgressProvider(plan.id)).valueOrNull ??
        const PlanProgress();

    final done = progress.doneCountIn(localized);
    final complete = progress.isComplete(localized);
    final next = progress.nextDay(localized);
    final nextNumber = next == null
        ? 0
        : days.indexWhere((d) => d.id == next.id) + 1;
    final locked = localized.premium && !ref.watch(hasPremiumAccessProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: CoverImage(imageUrl: localized.coverUrl, palette: 0),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Semantics(
                      button: true,
                      label: l10n.a11yBack,
                      child: Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              20,
              AppSpacing.screenPadding,
              32,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  localized.title,
                  style: AppTextStyles.display(fontSize: 28, color: p.text),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(text: l10n.planDayCount(days.length), p: p),
                    if (localized.premium)
                      _Chip(text: l10n.planPremiumBadge, p: p, accent: true),
                  ],
                ),
                if (localized.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    localized.description,
                    style: AppTextStyles.body(
                      fontSize: 15,
                      color: p.textMuted,
                    ).copyWith(height: 1.6),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  complete
                      ? l10n.planAllDone
                      : l10n.planProgress(done, days.length),
                  style: AppTextStyles.label(fontSize: 11.5, color: p.accent),
                ),
                const SizedBox(height: 12),
                if (next != null)
                  _PrimaryButton(
                    label: done == 0
                        ? l10n.planStart
                        : l10n.planContinue(nextNumber),
                    p: p,
                    onTap: () =>
                        _openDay(context, ref, next, nextNumber, l10n, p),
                  ),
                const SizedBox(height: 24),

                for (var i = 0; i < days.length; i++) ...[
                  _DayRow(
                    index: i + 1,
                    day: days[i],
                    done: progress.isDone(days[i].id),
                    locked: locked,
                    p: p,
                    l10n: l10n,
                    onTap: () =>
                        _openDay(context, ref, days[i], i + 1, l10n, p),
                  ),
                  if (i != days.length - 1) const SizedBox(height: 10),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.p, this.accent = false});

  final String text;
  final AppPalette p;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? p.accent.withValues(alpha: 0.14) : p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: accent ? p.accent : p.border, width: 0.5),
      ),
      child: Text(
        text,
        style: AppTextStyles.label(
          fontSize: 10,
          color: accent ? p.accent : p.textMuted,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.p,
    required this.onTap,
  });

  final String label;
  final AppPalette p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Text(
          label,
          style: AppTextStyles.label(fontSize: 11.5, color: p.onAccent),
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.index,
    required this.day,
    required this.done,
    required this.locked,
    required this.p,
    required this.l10n,
    required this.onTap,
  });

  final int index;
  final PlanDay day;
  final bool done;
  final bool locked;
  final AppPalette p;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? p.accent : p.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: done
                  ? Icon(Icons.check_rounded, size: 18, color: p.onAccent)
                  : Text(
                      '$index',
                      style: AppTextStyles.label(
                        fontSize: 11.5,
                        color: p.accent,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(fontSize: 13, color: p.text),
                  ),
                  if (done) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.planDayDone,
                      style: AppTextStyles.body(
                        fontSize: 11.5,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
              size: 20,
              color: p.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
