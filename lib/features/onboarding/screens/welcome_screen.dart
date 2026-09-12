import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/services/onboarding_timer.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/social_proof/social_proof_badge.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Karşılama (Ada tasarımı 01): wordmark, ada kartı, başlık, üç değer
/// satırı, "başla".
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    OnboardingTimer.start();
    unawaited(AnalyticsService.logOnboardingStarted());
    Future.microtask(
      () => ref.read(currentOnboardingStepProvider.notifier).state = (
        0,
        'welcome',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            // Kısa telefonda (SE) içerik kayar; uzun telefonda buton
            // ekranın dibine oturur.
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'ilnd.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(fontSize: 35, color: p.text),
                    ),
                    const SizedBox(height: 18),
                    IslandFrame(
                      p: p,
                      height: (constraints.maxWidth / 1.4).clamp(160.0, 250.0),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.welcomeHeadline,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(
                        fontSize: 28,
                        color: p.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.welcomeTagline,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 15,
                        color: p.textMuted,
                        height: 1.45,
                      ),
                    ),
                    // İki dilli marka dokunuşu: Türkçe satırın altında soluk
                    // İngilizcesi. İngilizce cihazda ikisi de aynı cümle olur ve
                    // sloganı iki kez yazardık — o yüzden yalnız Türkçede çizilir.
                    if (l10n.localeName.startsWith('tr'))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l10n.welcomeTaglineEn,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: p.textMuted.withValues(alpha: 0.75),
                          ).copyWith(letterSpacing: 0.2),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Üç değer önerisi satırı.
                    _Beat(
                      icon: Icons.eco_outlined,
                      text: l10n.welcomeBeatIsland,
                      p: p,
                    ),
                    const SizedBox(height: 12),
                    _Beat(
                      icon: Icons.chat_bubble_outline_rounded,
                      text: l10n.welcomeBeatMemory,
                      p: p,
                    ),
                    const SizedBox(height: 12),
                    _Beat(
                      icon: Icons.people_outline_rounded,
                      text: l10n.welcomeBeatCommunity,
                      p: p,
                    ),
                    const SizedBox(height: 24),
                    const Spacer(),
                    const SocialProofBadge(),
                    const SizedBox(height: 12),
                    IlndButton(
                      p: p,
                      label: l10n.welcomeStart,
                      onTap: () => context.push(routeQuickSetup),
                    ),
                    const SizedBox(height: 8),
                    // Zaten kayıtlı kullanıcı (yeni cihaz/web) doğrudan giriş
                    // yapıp profilini hidratlayabilsin — onboarding'i tekrar
                    // etmeden.
                    Center(
                      child: Pressable(
                        onTap: () => context.push(routeLogin),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: l10n.welcomeHaveAccount,
                                  style: AppTextStyles.body(
                                    fontSize: 13,
                                    color: p.textMuted,
                                  ),
                                ),
                                TextSpan(
                                  text: l10n.welcomeLoginLink,
                                  style: AppTextStyles.body(
                                    fontSize: 13,
                                    color: p.accent,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Değer önerisi satırı: Adaçayı ikon karosu + tek cümle.
class _Beat extends StatelessWidget {
  const _Beat({required this.icon, required this.text, required this.p});
  final IconData icon;
  final String text;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IlndIconTile(p: p, icon: icon, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body(fontSize: 14, color: p.text, height: 1.4),
          ),
        ),
      ],
    );
  }
}
