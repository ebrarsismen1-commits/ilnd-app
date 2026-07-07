import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/ilnd/ilnd_fallbacks.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/services/onboarding_timer.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Onboarding'in son adımı — auth'tan hemen sonra gösterilir. "Neye ihtiyacın
/// var?" sorusuna ILND'nin profile göre tahmin ettiği kısa şıkları sunar
/// (düşük-token AI çağrısı, offline'da sabit fallback). Bir şık seçilince
/// ILND sohbeti o ihtiyaçla açılır. Asla zorunlu değil: "şimdi değil" ile atlanır.
class FirstEntryScreen extends ConsumerStatefulWidget {
  const FirstEntryScreen({super.key});

  @override
  ConsumerState<FirstEntryScreen> createState() => _FirstEntryScreenState();
}

class _FirstEntryScreenState extends ConsumerState<FirstEntryScreen> {
  /// null → yükleniyor; sonra AI (veya fallback) şıkları.
  List<String>? _options;

  @override
  void initState() {
    super.initState();
    unawaited(_redeemPendingReferralCode());
    Future.microtask(
      () => ref.read(currentOnboardingStepProvider.notifier).state = (
        2,
        'first_entry',
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  Future<void> _redeemPendingReferralCode() async {
    final code = ref.read(referralCodeInputProvider);
    if (code == null || code.isEmpty) return;
    final repo = ref.read(referralRepositoryProvider);
    if (repo == null) return;
    final redeemed = await repo.redeemCode(code);
    if (redeemed) {
      unawaited(AnalyticsService.logReferralSignupCompleted());
      unawaited(AnalyticsService.logReferralRewardClaimed());
    }
    await ref.read(referralCodeInputProvider.notifier).clear();
  }

  Future<void> _loadOptions() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final memory = ref.read(ilndMemoryProvider);
    final service = ref.read(ilndServiceProvider);

    List<String> opts;
    try {
      opts = await service.suggestNeeds(memory: memory, l10n: l10n);
    } catch (_) {
      opts = const [];
    }
    // AI boş/başarısız → güvenli sabit şıklara düş.
    if (opts.isEmpty) opts = IlndFallbacks.needs(l10n);
    if (mounted) setState(() => _options = opts);
  }

  /// İlk-giriş adımını tamamlandı işaretler + sunucuya yazar (ADR-0003) +
  /// time-to-first-value ölçümünü kapatır.
  Future<void> _complete() async {
    await ref.read(firstEntryDoneProvider.notifier).setDone();
    unawaited(
      ref.read(profileRepositoryProvider)?.updateFields({
            'onboarding_done': true,
            'first_entry_done': true,
          }) ??
          Future<void>.value(),
    );
    ref.read(currentOnboardingStepProvider.notifier).state = null;
    final elapsed = OnboardingTimer.elapsed();
    if (elapsed != null) {
      unawaited(AnalyticsService.logTimeToFirstValue(elapsed));
    }
    OnboardingTimer.reset();
  }

  Future<void> _skip() async {
    unawaited(AnalyticsService.logEvent('onboarding_first_entry_skipped'));
    await _complete();
    if (mounted) context.go(routeHome);
  }

  Future<void> _pick(String need) async {
    unawaited(AnalyticsService.logEvent('onboarding_first_need_picked'));
    await _complete();
    if (!mounted) return;
    // Home'u tabana koy, sohbeti seçilen ihtiyaçla üstüne aç — sohbet
    // kapanınca kullanıcı home'a düşer.
    context.go(routeHome);
    context.push(routeChat, extra: need);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final options = _options;

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.firstEntryHeader,
                      style: AppTextStyles.sectionLabel(color: p.textMuted),
                    ),
                    Pressable(
                      onTap: _skip,
                      child: Text(
                        l10n.firstEntrySkip,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: p.textMuted,
                        ).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  l10n.firstEntryNeedsPrompt,
                  style: AppTextStyles.display(fontSize: 30, color: p.text),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: options == null
                    ? _LoadingOptions(p: p, label: l10n.firstEntryNeedsLoading)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _NeedOption(
                          label: options[i],
                          p: p,
                          onTap: () => _pick(options[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingOptions extends StatelessWidget {
  const _LoadingOptions({required this.p, required this.label});
  final AppPalette p;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BreathRing(size: 48),
          const SizedBox(height: 16),
          Text(
            label,
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

class _NeedOption extends StatelessWidget {
  const _NeedOption({
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: p.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body(
                  fontSize: 16,
                  color: p.text,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 18, color: p.accent),
          ],
        ),
      ),
    );
  }
}
