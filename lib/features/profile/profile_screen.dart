import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/reminder_provider.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/auth/auth_error_l10n.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/features/profile/avatar_edit.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final onboardingName = ref.watch(userNameProvider);
    final name = onboardingName.isNotEmpty
        ? onboardingName
        : ref.watch(ilndMemoryProvider).name;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                28,
                AppSpacing.screenPadding,
                32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  Entrance(
                    index: 0,
                    child: _ProfileHeader(name: name, initial: initial, p: p),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Entrance(
                    index: 1,
                    child: _StatsRow(p: p, ref: ref),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Entrance(index: 2, child: _MemoryCard(p: p)),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Entrance(
                    index: 3,
                    child: _BadgesSection(p: p, ref: ref),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Entrance(
                    index: 4,
                    child: _WeeklySummaryCard(p: p, ref: ref),
                  ),
                  const SizedBox(height: 12),
                  Entrance(
                    index: 5,
                    child: Pressable(
                      onTap: () => context.push(routeVibeCard),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radius,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                              color: p.accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.profileShareWeeklySummary,
                                style: AppTextStyles.body(
                                  fontSize: 15,
                                  color: p.text,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: p.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Entrance(index: 6, child: _SettingsSection(p: p)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile header ───────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.name,
    required this.initial,
    required this.p,
  });
  final String name;
  final String initial;
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: l10n.a11yEditPhoto,
          child: Pressable(
            onTap: () => showAvatarOptions(context, ref),
            child: Stack(
              children: [
                UserAvatar(size: 60, initial: initial, p: p, fontSize: 24),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.base, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 11,
                      color: p.onAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Ölçek zıtlığı: bu ekranın tek büyük anı — kişinin adı, serif.
        Text(
          name.isNotEmpty ? name : l10n.profileDefaultUserName,
          style: AppTextStyles.display(
            fontSize: 30,
            color: p.text,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${name.toLowerCase().replaceAll(' ', '_')}_ilnd',
          style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
        ),
      ],
    );
  }
}

// ─── Memory card — "ILND seni hatırlıyor" ────────────────────────────────────

class _MemoryCard extends ConsumerWidget {
  const _MemoryCard({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final memory = ref.watch(ilndMemoryProvider);
    final goals = memory.goals;
    final facts = memory.facts;
    if (goals.isEmpty && facts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BreathRing(size: 28),
              const SizedBox(width: 10),
              Text(
                l10n.profileMemoryHeading,
                style: AppTextStyles.heading(fontSize: 15, color: p.text),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (goals.isNotEmpty) ...[
            Text(
              l10n.profileGoalsLabel,
              style: AppTextStyles.sectionLabel(color: p.accent),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in goals)
                  _MemoryChip(label: g, accent: true, p: p),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (facts.isNotEmpty) ...[
            Text(
              l10n.profileAboutYouLabel,
              style: AppTextStyles.sectionLabel(color: p.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in facts)
                  _MemoryChip(label: f, accent: false, p: p),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({
    required this.label,
    required this.accent,
    required this.p,
  });
  final String label;
  final bool accent;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent ? p.accentSoft.withValues(alpha: 0.3) : p.surfaceStrong,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Text(
        label,
        style: AppTextStyles.body(
          fontSize: 13,
          color: accent ? p.accent : p.text,
        ),
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.p, required this.ref});
  final AppPalette p;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(profileStatsProvider);
    final streak = statsAsync.valueOrNull?.streakDays ?? 0;
    final journalCount = statsAsync.valueOrNull?.weeklyJournalCount ?? 0;
    final foodCount = statsAsync.valueOrNull?.weeklyFoodCount ?? 0;
    final puan = streak * 10 + journalCount * 5 + foodCount * 3;
    final islandItems =
        ref.watch(islandStateProvider).valueOrNull?.earnedCount ?? 0;

    // Handoff §5: üç ayrı kart değil, hairline'la çerçevelenmiş TEK şerit.
    // Kartlar üç sayıyı üç ayrı nesne gibi gösteriyordu; oysa bunlar aynı
    // cümlenin üç kelimesi.
    return Column(
      children: [
        Container(height: 0.5, color: p.border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '$streak',
                  label: l10n.profileStatStreak,
                  p: p,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '$puan',
                  label: l10n.profileStatPoints,
                  p: p,
                ),
              ),
              Expanded(
                child: _Stat(
                  // Eskiden `streak >= 7 ? 2 : 1` yazan uydurma bir "rozet"
                  // sayacıydı — hiçbir şeyi saymıyordu. Artık sunucunun
                  // verdiği gerçek ada öğesi sayısı (ADR-0006).
                  value: '$islandItems',
                  label: l10n.profileStatIslandItems,
                  p: p,
                ),
              ),
            ],
          ),
        ),
        Container(height: 0.5, color: p.border),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.p});
  final String value;
  final String label;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.mono(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.label(fontSize: 9.5, color: p.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Badges section ───────────────────────────────────────────────────────────

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({required this.p, required this.ref});
  final AppPalette p;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stats =
        ref.watch(profileStatsProvider).valueOrNull ?? ProfileStats.zero;
    final hasFirstEntry =
        stats.weeklyJournalCount > 0 ||
        stats.weeklyFoodCount > 0 ||
        stats.streakDays > 0;
    final hasWeekStreak = stats.streakDays >= 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.profileBadgesLabel,
          style: AppTextStyles.sectionLabel(color: p.textMuted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BadgeCard(
                icon: Icons.star_border_rounded,
                label: l10n.profileBadgeFirstStep,
                color: p.accent,
                locked: !hasFirstEntry,
                p: p,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BadgeCard(
                icon: Icons.local_fire_department_rounded,
                label: l10n.profileBadgeSevenDays,
                color: p.amber,
                locked: !hasWeekStreak,
                p: p,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BadgeCard(
                icon: Icons.menu_book_rounded,
                label: l10n.profileBadgeReader,
                color: p.accent,
                locked: true,
                p: p,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BadgeCard(
                icon: Icons.emoji_events_rounded,
                label: l10n.profileBadgeThirtyDays,
                color: p.amber,
                locked: stats.streakDays < 30,
                p: p,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.locked,
    required this.p,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool locked;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: locked ? p.surfaceStrong : p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: locked ? 0.4 : 1.0,
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.label(
              fontSize: 10,
              color: locked ? p.textMuted.withValues(alpha: 0.6) : color,
            ).copyWith(letterSpacing: 0.3),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Weekly summary card ──────────────────────────────────────────────────────

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({required this.p, required this.ref});
  final AppPalette p;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayLabels = l10n.profileWeekdaysShort.split(',');
    final statsAsync = ref.watch(profileStatsProvider);
    final stats = statsAsync.valueOrNull ?? ProfileStats.zero;
    final barValues = stats.weeklyActivityByDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.profileWeeklySummaryLabel,
          style: AppTextStyles.sectionLabel(color: p.textMuted),
        ),
        Text(
          l10n.profileThisWeek,
          style: AppTextStyles.display(fontSize: 19, color: p.text),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    value: '${stats.weeklyFoodCount}',
                    label: l10n.profileMealsAdded,
                    p: p,
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    value: '${stats.streakDays}',
                    label: l10n.profileDayStreak,
                    p: p,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    value: '${stats.weeklyJournalCount}',
                    label: l10n.profileJournalEntriesWritten,
                    p: p,
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    value: statsAsync.isLoading ? '…' : '✓',
                    label: l10n.profileSynced,
                    p: p,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Divider(height: 0.5, thickness: 0.5, color: p.border),
        const SizedBox(height: 16),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(barValues.length, (i) {
              final value = barValues[i];
              final isEmpty = value == 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              width: double.infinity,
                              height: isEmpty ? 4 : 76 * value,
                              decoration: BoxDecoration(
                                color: isEmpty ? p.surfaceStrong : p.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayLabels[i],
                        style: AppTextStyles.mono(
                          fontSize: 9.5,
                          color: isEmpty
                              ? p.textMuted.withValues(alpha: 0.5)
                              : p.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.value,
    required this.label,
    required this.p,
  });
  final String value;
  final String label;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: AppTextStyles.mono(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body(fontSize: 11.5, color: p.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Settings section ─────────────────────────────────────────────────────────

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pressable(
          onTap: isPremium
              ? null
              : () => PaywallScreen.show(context, source: 'profile'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isPremium ? p.surface : p.accent,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(
                color: isPremium ? p.border : p.accent,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPremium ? Icons.verified_rounded : Icons.star_rounded,
                  size: 20,
                  color: isPremium ? p.accent : p.onAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isPremium
                        ? l10n.profilePremiumMember
                        : l10n.profileGoPremium,
                    style: AppTextStyles.body(
                      fontSize: 15,
                      color: isPremium ? p.text : p.onAccent,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!isPremium)
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: p.onAccent,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Text(
          l10n.profileSettingsLabel,
          style: AppTextStyles.sectionLabel(color: p.textMuted),
        ),
        const SizedBox(height: 10),
        // Takip tekrar kendi ekrani (tasarim handoff §5 ayarlar listesi):
        // Bugun'deki sessiz satirin yaninda buradan da acilir.
        Pressable(
          onTap: () => context.push(routePreferences),
          child: _SettingsRow(
            icon: Icons.tune_rounded,
            label: l10n.profilePreferences,
            p: p,
          ),
        ),
        Pressable(
          onTap: () => context.push(routeTakip),
          child: _SettingsRow(
            icon: Icons.insights_outlined,
            label: l10n.takipTitle,
            p: p,
          ),
        ),
        Pressable(
          onTap: () => context.push(routeReferral),
          child: _SettingsRow(
            icon: Icons.card_giftcard_rounded,
            label: l10n.profileInviteFriend,
            showChevron: true,
            p: p,
          ),
        ),
        const SizedBox(height: 8),
        _ReminderSettingRow(p: p),
        // "Ayarlar" satırı kaldırıldı: chevron'la tıklanabilir görünüyordu
        // ama hiçbir yere gitmiyordu (sahte özellik). Gerçek ayar olan
        // günlük hatırlatma zaten yukarıda satır içi yaşıyor.
        const SizedBox(height: 8),
        Pressable(
          onTap: () => context.push(routePrivacyPolicy),
          child: _SettingsRow(
            icon: Icons.privacy_tip_outlined,
            label: l10n.profilePrivacyPolicy,
            showChevron: true,
            p: p,
          ),
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: () => context.push(routeTermsOfService),
          child: _SettingsRow(
            icon: Icons.description_outlined,
            label: l10n.profileTermsOfService,
            showChevron: true,
            p: p,
          ),
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: () async {
            await ref.read(authNotifierProvider.notifier).signOut();
            if (context.mounted) IlndToast.info(context, l10n.profileSignedOut);
          },
          child: _SettingsRow(
            icon: Icons.logout_rounded,
            label: l10n.profileSignOut,
            labelColor: p.danger,
            iconColor: p.danger,
            showChevron: false,
            p: p,
          ),
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: () => _confirmDeleteAccount(context, ref),
          child: _SettingsRow(
            icon: Icons.delete_forever_rounded,
            label: l10n.profileDeleteAccount,
            labelColor: p.danger,
            iconColor: p.danger,
            showChevron: false,
            p: p,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.read(paletteProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileDeleteAccountDialogTitle),
        content: Text(l10n.profileDeleteAccountDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileDeleteAccountCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.profileDeleteAccountConfirm,
              style: TextStyle(color: p.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(authNotifierProvider.notifier).deleteAccount();
      if (!context.mounted) return;
      Navigator.of(context).pop(); // loading dialog
      IlndToast.info(context, l10n.profileAccountDeleted);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // loading dialog
      final message = e is AuthErrorCode
          ? e.localized(l10n)
          : l10n.authErrorDeleteFailed;
      IlndToast.error(context, message);
    }
  }
}

/// Günlük hatırlatma ayarı: toggle + (açıkken) saat satırı.
/// Toggle açılırken bildirim izni istenir; reddedilirse kapalı kalır ve
/// kullanıcıya cihaz ayarları yolu gösterilir. Metinler l10n'den (Kural #1).
class _ReminderSettingRow extends ConsumerWidget {
  const _ReminderSettingRow({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(reminderProvider);
    final time = TimeOfDay(
      hour: settings.hour,
      minute: settings.minute,
    ).format(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: p.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reminderSettingLabel,
                      style: AppTextStyles.body(
                        fontSize: 15,
                        color: p.text,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      l10n.reminderSettingSubtitle,
                      style: AppTextStyles.body(
                        fontSize: 11.5,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: settings.enabled,
                activeThumbColor: p.accent,
                onChanged: (on) => _toggle(context, ref, on),
              ),
            ],
          ),
          if (settings.enabled)
            Pressable(
              onTap: () => _pickTime(context, ref),
              child: Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.reminderTimeLabel(time),
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: p.accent,
                        ),
                      ),
                    ),
                    Icon(Icons.edit_outlined, size: 16, color: p.textMuted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(reminderProvider.notifier);
    if (!on) {
      await notifier.disable();
      return;
    }
    final granted = await notifier.enable(
      title: l10n.reminderNotificationTitle,
      body: l10n.reminderNotificationBody,
      channelName: l10n.reminderSettingLabel,
      hasActivityToday: ref.read(todaysMoodProvider) != null,
    );
    if (!granted && context.mounted) {
      IlndToast.info(context, l10n.reminderPermissionDenied);
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.read(reminderProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
    );
    if (picked == null || !context.mounted) return;
    await ref
        .read(reminderProvider.notifier)
        .setTime(
          hour: picked.hour,
          minute: picked.minute,
          title: l10n.reminderNotificationTitle,
          body: l10n.reminderNotificationBody,
          channelName: l10n.reminderSettingLabel,
          hasActivityToday: ref.read(todaysMoodProvider) != null,
        );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.labelColor,
    this.iconColor,
    this.showChevron = true,
    required this.p,
  });

  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color? iconColor;
  final bool showChevron;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 19, color: iconColor ?? p.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body(
                    fontSize: 14.5,
                    color: labelColor ?? p.text,
                  ),
                ),
              ),
              if (showChevron)
                Icon(Icons.chevron_right_rounded, size: 19, color: p.textMuted),
            ],
          ),
        ),
        Container(height: 0.5, color: p.border),
      ],
    );
  }
}
