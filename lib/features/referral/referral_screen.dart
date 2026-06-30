import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/referral/redeem_code_sheet.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    // Ödülü olan davet eden kullanıcı uygulamayı açtığında lokal premium
    // entitlement'ı senkronize et — sunucu taraflı bir doğrulama yok (P0),
    // bu yüzden sadece bu cihazda görünür olur.
    Future.microtask(() async {
      final profile = await ref.read(myGrowthProfileProvider.future);
      if (profile != null && profile.hasActivePremiumReward && mounted) {
        await ref.read(isPremiumProvider.notifier).setPremium(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final profileAsync = ref.watch(myGrowthProfileProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    8,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back_rounded, color: p.text),
                        tooltip: l10n.a11yBack,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  8,
                  AppSpacing.screenPadding,
                  32,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    Entrance(
                      index: 0,
                      child: Text(
                        l10n.referralTitle,
                        style: AppTextStyles.display(
                          fontSize: 28,
                          color: p.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Entrance(
                      index: 1,
                      child: Text(
                        l10n.referralSubtitle,
                        style: AppTextStyles.body(
                          fontSize: 14,
                          color: p.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Entrance(
                      index: 2,
                      child: profileAsync.when(
                        loading: () => const _CodeCardSkeleton(),
                        error: (e, st) => _CodeLoadError(
                          p: p,
                          onRetry: () =>
                              ref.invalidate(myGrowthProfileProvider),
                        ),
                        data: (profile) => _CodeCard(
                          code: profile?.referralCode ?? '',
                          founding: profile?.foundingMember ?? false,
                          p: p,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Entrance(
                      index: 3,
                      child: Pressable(
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          barrierColor: AppColors.charcoal.withValues(
                            alpha: 0.45,
                          ),
                          isScrollControlled: true,
                          builder: (ctx) => const RedeemCodeSheet(),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radius,
                            ),
                            border: Border.all(color: p.border, width: 0.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.referralEnterCode,
                            style: AppTextStyles.body(
                              fontSize: 14,
                              color: p.accent,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
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

class _CodeCardSkeleton extends StatelessWidget {
  const _CodeCardSkeleton();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 180);
}

class _CodeLoadError extends StatelessWidget {
  const _CodeLoadError({required this.p, required this.onRetry});
  final AppPalette p;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.referralCodeLoadError,
            style: AppTextStyles.heading(fontSize: 16, color: p.text),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.referralCodeLoadErrorBody,
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
          ),
          const SizedBox(height: 14),
          Pressable(
            onTap: onRetry,
            child: Text(
              l10n.referralRetry,
              style: AppTextStyles.body(
                fontSize: 14,
                color: p.accent,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends ConsumerWidget {
  const _CodeCard({
    required this.code,
    required this.founding,
    required this.p,
  });
  final String code;
  final bool founding;
  final AppPalette p;

  Future<void> _copy(BuildContext context, AppLocalizations l10n) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) IlndToast.success(context, l10n.referralCodeCopied);
  }

  Future<void> _share(BuildContext context, AppLocalizations l10n) async {
    await Share.share(
      l10n.referralShareText(code),
      subject: l10n.referralShareSubject,
    );
    unawaited(AnalyticsService.logReferralLinkShared('share_sheet'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (founding) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.referralFoundingMember,
                style: AppTextStyles.label(
                  fontSize: 10,
                  color: p.amber,
                ).copyWith(letterSpacing: 0.4),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            l10n.referralYourCode,
            style: AppTextStyles.sectionLabel(color: p.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            code.isEmpty ? '······' : code,
            style: AppTextStyles.mono(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: p.text,
            ).copyWith(letterSpacing: 4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: code.isEmpty ? null : () => _copy(context, l10n),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: p.surfaceStrong,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.referralCopy,
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: p.text,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  onTap: code.isEmpty ? null : () => _share(context, l10n),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.referralShare,
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: p.onAccent,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
