import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/auth/auth_error_l10n.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/features/profile/avatar_edit.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

const _danger = Color(0xFFB3554A);

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
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
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
                            border: Border.all(color: p.border, width: 0.5),
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
                UserAvatar(size: 60, initial: initial, p: p, fontSize: 26),
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
        border: Border.all(color: p.border, width: 0.5),
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
                style: AppTextStyles.heading(fontSize: 17, color: p.text),
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

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$streak',
            label: l10n.profileStatStreak,
            suffix: ' 🔥',
            p: p,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(value: '$puan', label: l10n.profileStatPoints, p: p),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: streak >= 7 ? '2' : '1',
            label: l10n.profileStatBadge,
            p: p,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.suffix = '',
    required this.p,
  });
  final String value;
  final String label;
  final String suffix;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            '$value$suffix',
            style: AppTextStyles.mono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTextStyles.label(
              fontSize: 10,
              color: p.textMuted,
            ).copyWith(letterSpacing: 0.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
                emoji: '⭐',
                label: l10n.profileBadgeFirstStep,
                color: p.accent,
                locked: !hasFirstEntry,
                p: p,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BadgeCard(
                emoji: '🔥',
                label: l10n.profileBadgeSevenDays,
                color: p.amber,
                locked: !hasWeekStreak,
                p: p,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BadgeCard(
                emoji: '📖',
                label: l10n.profileBadgeReader,
                color: p.accent,
                locked: true,
                p: p,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BadgeCard(
                emoji: '🏆',
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
    required this.emoji,
    required this.label,
    required this.color,
    required this.locked,
    required this.p,
  });
  final String emoji;
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
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.label(
              fontSize: 9,
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileWeeklySummaryLabel,
            style: AppTextStyles.sectionLabel(color: p.textMuted),
          ),
          Text(
            l10n.profileThisWeek,
            style: AppTextStyles.display(fontSize: 20, color: p.text),
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
            height: 64,
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
                                height: isEmpty ? 4 : 48 * value,
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
                          style: AppTextStyles.label(
                            fontSize: 9,
                            color: isEmpty
                                ? p.textMuted.withValues(alpha: 0.5)
                                : p.accent,
                          ).copyWith(letterSpacing: 0),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
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
          onTap: isPremium ? null : () => PaywallScreen.show(context),
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
        // Takip ana sayfaya taşındı (Web Raporu madde 6) — buradan kaldırıldı.
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
        Pressable(
          onTap: () {},
          child: _SettingsRow(
            icon: Icons.settings_outlined,
            label: l10n.profileSettingsRow,
            showChevron: true,
            p: p,
          ),
        ),
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
            labelColor: _danger,
            iconColor: _danger,
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
            labelColor: _danger,
            iconColor: _danger,
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
              style: const TextStyle(color: _danger),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? p.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body(
                fontSize: 15,
                color: labelColor ?? p.text,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (showChevron)
            Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
        ],
      ),
    );
  }
}
