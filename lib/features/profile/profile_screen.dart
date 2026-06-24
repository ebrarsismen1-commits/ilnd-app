import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';

const _danger = Color(0xFFB3554A);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    Entrance(index: 0, child: _ProfileHeader(name: name, initial: initial, p: p)),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(index: 1, child: _StatsRow(p: p)),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(index: 2, child: _MemoryCard(p: p)),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(index: 3, child: _BadgesSection(p: p)),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(index: 4, child: _WeeklySummaryCard(p: p)),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(index: 5, child: _SettingsSection(p: p)),
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.initial, required this.p});
  final String name;
  final String initial;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(initial,
              style: AppTextStyles.heading(fontSize: 24, color: p.onAccent)),
        ),
        const SizedBox(height: 14),
        Text(name.isNotEmpty ? name : 'Kullanıcı',
            style: AppTextStyles.heading(fontSize: 22, color: p.text)),
        const SizedBox(height: 3),
        Text('@${name.toLowerCase().replaceAll(' ', '_')}_ilnd',
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted)),
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
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('i',
                    style: AppTextStyles.display(fontSize: 14, color: p.onAccent)),
              ),
              const SizedBox(width: 10),
              Text('ILND seni hatırlıyor',
                  style: AppTextStyles.heading(fontSize: 17, color: p.text)),
            ],
          ),
          const SizedBox(height: 16),
          if (goals.isNotEmpty) ...[
            Text('HEDEFLERİN', style: AppTextStyles.sectionLabel(color: p.accent)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final g in goals) _MemoryChip(label: g, accent: true, p: p)],
            ),
            const SizedBox(height: 16),
          ],
          if (facts.isNotEmpty) ...[
            Text('SENİN HAKKINDA', style: AppTextStyles.sectionLabel(color: p.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final f in facts) _MemoryChip(label: f, accent: false, p: p)],
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({required this.label, required this.accent, required this.p});
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
      child: Text(label,
          style: AppTextStyles.body(
              fontSize: 13, color: accent ? p.accent : p.text)),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(value: '12', label: 'seri', suffix: ' 🔥', p: p)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '340', label: 'toplam puan', p: p)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '7', label: 'rozet', p: p)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, this.suffix = '', required this.p});
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
          Text('$value$suffix',
              style: AppTextStyles.mono(fontSize: 22, fontWeight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 3),
          Text(label,
              style: AppTextStyles.label(fontSize: 10, color: p.textMuted)
                  .copyWith(letterSpacing: 0.4),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Badges section ───────────────────────────────────────────────────────────

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ROZETLER', style: AppTextStyles.sectionLabel(color: p.textMuted)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _BadgeCard(emoji: '⭐', label: 'ilk adım', color: p.accent, locked: false, p: p)),
            const SizedBox(width: 10),
            Expanded(child: _BadgeCard(emoji: '🔥', label: '7 günlük', color: p.amber, locked: false, p: p)),
            const SizedBox(width: 10),
            Expanded(child: _BadgeCard(emoji: '📖', label: 'okur', color: p.accent, locked: false, p: p)),
            const SizedBox(width: 10),
            Expanded(child: _BadgeCard(emoji: '🔒', label: 'kilit', color: p.textMuted, locked: true, p: p)),
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
          Opacity(opacity: locked ? 0.4 : 1.0, child: Text(emoji, style: const TextStyle(fontSize: 22))),
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
  const _WeeklySummaryCard({required this.p});
  final AppPalette p;

  static const _barValues = [0.7, 0.9, 0.5, 1.0, 0.4, 0.0, 0.0];
  static const _dayLabels = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];

  @override
  Widget build(BuildContext context) {
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
          Text('HAFTALIK ÖZET', style: AppTextStyles.sectionLabel(color: p.textMuted)),
          Text('bu hafta', style: AppTextStyles.display(fontSize: 20, color: p.text)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryRow(value: '3', label: 'içerik okundu', p: p),
                    const SizedBox(height: 10),
                    _SummaryRow(value: '4.2k', label: 'ort. adım', p: p),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryRow(value: '2', label: 'günlük yazıldı', p: p),
                    const SizedBox(height: 10),
                    _SummaryRow(value: '1.8L', label: 'ort. su', p: p),
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
              children: List.generate(_barValues.length, (i) {
                final value = _barValues[i];
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
                          _dayLabels[i],
                          style: AppTextStyles.label(
                            fontSize: 9,
                            color: isEmpty ? p.textMuted.withValues(alpha: 0.5) : p.accent,
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
  const _SummaryRow({required this.value, required this.label, required this.p});
  final String value;
  final String label;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value,
            style: AppTextStyles.mono(fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(label,
              style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
              overflow: TextOverflow.ellipsis),
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
              border: Border.all(color: isPremium ? p.border : p.accent, width: 0.5),
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
                    isPremium ? 'ILND+ üyesisin' : 'ILND+’a geç',
                    style: AppTextStyles.body(
                      fontSize: 15,
                      color: isPremium ? p.text : p.onAccent,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!isPremium)
                  Icon(Icons.arrow_forward_rounded, size: 20, color: p.onAccent),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Text('AYARLAR', style: AppTextStyles.sectionLabel(color: p.textMuted)),
        const SizedBox(height: 10),
        Pressable(
          onTap: () {},
          child: _SettingsRow(icon: Icons.settings_outlined, label: 'ayarlar', showChevron: true, p: p),
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) IlndToast.info(context, 'Çıkış yapıldı. Görüşürüz 👋');
            },
          child: _SettingsRow(
            icon: Icons.logout_rounded,
            label: 'çıkış yap',
            labelColor: _danger,
            iconColor: _danger,
            showChevron: false,
            p: p,
          ),
        ),
      ],
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
              style: AppTextStyles.body(fontSize: 15, color: labelColor ?? p.text)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (showChevron)
            Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
        ],
      ),
    );
  }
}
