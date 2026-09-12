import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/features/auth/auth_error_l10n.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Verilerin ve gizlilik (Ada tasarımı 17'nin bugün karşılanabilen hâli).
///
/// Tasarımdaki "sohbette kullanılsın / önerilerde kullanılsın" anahtarları
/// ve "kayıtlarını indir" henüz bir backend karşılığı olmadığı için yok:
/// çalışmayan bir anahtar, verisi kutsal olan kullanıcıya yalan söylemek
/// olurdu (PROJECT_PRINCIPLES #1). Burada olan her şey gerçek: ILND'nin
/// hatırladıkları, belgeler ve hesabı silme.
class DataPrivacyScreen extends ConsumerWidget {
  const DataPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            32,
          ),
          children: [
            IlndPageHeader(
              p: p,
              title: l10n.dataTitle,
              subtitle: l10n.dataSubtitle,
            ),
            const SizedBox(height: 24),
            _MemoryCard(p: p),
            const SizedBox(height: 16),
            IlndListRow(
              p: p,
              icon: Icons.privacy_tip_outlined,
              title: l10n.profilePrivacyPolicy,
              onTap: () => context.push(routePrivacyPolicy),
            ),
            const SizedBox(height: 10),
            IlndListRow(
              p: p,
              icon: Icons.description_outlined,
              title: l10n.profileTermsOfService,
              onTap: () => context.push(routeTermsOfService),
            ),
            const SizedBox(height: 10),
            IlndListRow(
              p: p,
              icon: Icons.delete_outline_rounded,
              iconColor: p.danger,
              title: l10n.profileDeleteAccount,
              titleColor: p.danger,
              onTap: () => _confirmDeleteAccount(context, ref),
            ),
          ],
        ),
      ),
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

/// "ILND seni hatırlıyor": hedefler ve öğrenilmiş bilgiler. Sen ekranından
/// buraya taşındı; hafıza bir profil süsü değil, verinin kendisi.
class _MemoryCard extends ConsumerWidget {
  const _MemoryCard({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final memory = ref.watch(ilndMemoryProvider);
    final goals = memory.goals;
    final facts = memory.facts;

    return IlndCard(
      p: p,
      color: p.surfaceStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BreathRing(size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.profileMemoryHeading,
                  style: AppTextStyles.serifTitle(color: p.text, fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (goals.isEmpty && facts.isEmpty)
            Text(
              l10n.dataMemoryEmpty,
              style: AppTextStyles.body(
                fontSize: 13,
                color: p.textMuted,
                height: 1.5,
              ),
            ),
          if (goals.isNotEmpty) ...[
            Text(
              l10n.profileGoalsLabel,
              style: AppTextStyles.caption(color: p.accent),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final g in goals) _Chip(label: g, p: p)],
            ),
            const SizedBox(height: 14),
          ],
          if (facts.isNotEmpty) ...[
            Text(
              l10n.profileAboutYouLabel,
              style: AppTextStyles.caption(color: p.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final f in facts) _Chip(label: f, p: p)],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.p});
  final String label;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Text(
        label,
        style: AppTextStyles.body(fontSize: 13, color: p.text),
      ),
    );
  }
}
