import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/utils/possessive.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/features/profile/avatar_edit.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Sen (Ada tasarımı 10): kimlik, haftanın özeti, dört kapı.
///
/// 2026-09-11'de sadeleşti. Sayı şeridi, rozetler ve haftalık çubuk grafik
/// tasarımda yok; haftanın özeti artık tek bir kartta ve streak kartına
/// açılıyor. ILND'nin hafızası "Verilerin ve gizlilik"e, günlük hatırlatma
/// "Bildirim tercihlerin"e, hesabı silme de verilerin yanına taşındı: Sen
/// ekranı ayar listesi değil, kişinin kendisi.
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

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            12,
            AppSpacing.screenPadding,
            32,
          ),
          children: [
            Entrance(
              index: 0,
              child: IlndPageHeader(
                p: p,
                title: l10n.navYou,
                subtitle: l10n.profileTagline,
                showBack: false,
                titleSize: 28,
                trailing: Semantics(
                  button: true,
                  label: l10n.profilePreferences,
                  child: Pressable(
                    onTap: () => context.push(routePreferences),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.settings_outlined,
                        size: 22,
                        color: p.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Entrance(
              index: 1,
              child: _Identity(name: name, p: p),
            ),
            const SizedBox(height: 20),
            Entrance(index: 2, child: _WeekCard(p: p)),
            const SizedBox(height: 16),
            Entrance(
              index: 3,
              child: Column(
                children: [
                  IlndListRow(
                    p: p,
                    icon: Icons.eco_outlined,
                    title: name.isEmpty
                        ? l10n.adanTitle
                        : l10n.homeIslandOwned(possessiveName(l10n, name)),
                    subtitle: l10n.profileIslandRowSubtitle,
                    onTap: () => context.push(routeAdan),
                  ),
                  const SizedBox(height: 10),
                  IlndListRow(
                    p: p,
                    icon: Icons.schedule_rounded,
                    title: l10n.profileNotificationsRow,
                    subtitle: l10n.profileNotificationsRowSubtitle,
                    onTap: () => context.push(routeNotificationPrefs),
                  ),
                  const SizedBox(height: 10),
                  IlndListRow(
                    p: p,
                    icon: Icons.lock_outline_rounded,
                    title: l10n.profileDataRow,
                    subtitle: l10n.profileDataRowSubtitle,
                    onTap: () => context.push(routeDataPrivacy),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Entrance(index: 4, child: _PlusCard(p: p)),
            const SizedBox(height: 28),
            Text(
              l10n.profileSettingsLabel,
              style: AppTextStyles.sectionLabel(color: p.textMuted),
            ),
            const SizedBox(height: 10),
            IlndListRow(
              p: p,
              icon: Icons.auto_awesome_outlined,
              title: l10n.profileShareWeeklySummary,
              onTap: () => context.push(routeVibeCard),
            ),
            const SizedBox(height: 10),
            IlndListRow(
              p: p,
              icon: Icons.card_giftcard_outlined,
              title: l10n.profileInviteFriend,
              onTap: () => context.push(routeReferral),
            ),
            const SizedBox(height: 10),
            IlndListRow(
              p: p,
              icon: p.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              title: l10n.profileNightView,
              semanticsLabel: l10n.a11yToggleTheme,
              trailing: Switch.adaptive(
                value: p.isDark,
                activeThumbColor: p.accent,
                onChanged: (on) => ref.read(themeModeProvider.notifier).state =
                    on ? Brightness.dark : Brightness.light,
              ),
            ),
            const SizedBox(height: 10),
            IlndListRow(
              p: p,
              icon: Icons.logout_rounded,
              iconColor: p.danger,
              title: l10n.profileSignOut,
              titleColor: p.danger,
              trailing: const SizedBox.shrink(),
              onTap: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  IlndToast.info(context, l10n.profileSignedOut);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Kimlik ───────────────────────────────────────────────────────────────────

class _Identity extends ConsumerWidget {
  const _Identity({required this.name, required this.p});
  final String name;
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      children: [
        Semantics(
          button: true,
          label: l10n.a11yEditPhoto,
          child: Pressable(
            onTap: () => showAvatarOptions(context, ref),
            child: Stack(
              children: [
                UserAvatar(size: 68, initial: initial, p: p, fontSize: 26),
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
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isNotEmpty ? name : l10n.profileDefaultUserName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display(fontSize: 25, color: p.text),
              ),
              const SizedBox(height: 2),
              Text(
                '@${name.toLowerCase().replaceAll(' ', '_')}_ilnd',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(fontSize: 14, color: p.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Bu haftadan kalanlar ────────────────────────────────────────────────────

/// Haftanın tek cümlelik özeti; dokunulunca streak/hafta kartı açılır.
class _WeekCard extends ConsumerWidget {
  const _WeekCard({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stats =
        ref.watch(profileStatsProvider).valueOrNull ?? ProfileStats.zero;
    return IlndCard(
      p: p,
      color: p.surfaceStrong,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      onTap: () => context.push(routeStreakCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileWeekLabel,
            style: AppTextStyles.caption(color: p.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.profileWeekLine(
              stats.weeklyJournalCount,
              stats.weeklyFoodCount,
            ),
            style: AppTextStyles.serifTitle(color: p.text, fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.profileWeekHint,
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── ILND+ ────────────────────────────────────────────────────────────────────

class _PlusCard extends ConsumerWidget {
  const _PlusCard({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumProvider);
    return IlndCard(
      p: p,
      color: p.sea,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      onTap: isPremium
          ? null
          : () => PaywallScreen.show(context, source: 'profile'),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isPremium ? l10n.profilePremiumMember : l10n.profileGoPremium,
              style: AppTextStyles.body(
                fontSize: 15,
                color: p.accent,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Icon(
            isPremium ? Icons.verified_outlined : Icons.arrow_forward_rounded,
            size: 20,
            color: p.accent,
          ),
        ],
      ),
    );
  }
}
