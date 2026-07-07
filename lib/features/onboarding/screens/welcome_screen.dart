import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/services/onboarding_timer.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/social_proof/social_proof_badge.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

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
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 3),
                Text(
                  'ilnd.',
                  style: AppTextStyles.displayHero().copyWith(color: p.text),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.welcomeTagline,
                  style: AppTextStyles.body(
                    fontSize: 18,
                    color: p.textMuted,
                  ).copyWith(letterSpacing: 0.2),
                ),
                Text(
                  l10n.welcomeTaglineEn,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: p.textMuted.withValues(alpha: 0.7),
                  ).copyWith(letterSpacing: 0.2),
                ),
                const Spacer(flex: 4),
                const SocialProofBadge(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  // AppTheme.dark artık MaterialApp'e bağlı (main.dart) —
                  // ElevatedButtonThemeData zaten aktif moda göre doğru
                  // rengi veriyor, manuel override'a gerek yok.
                  child: ElevatedButton(
                    onPressed: () => context.push(routeQuickSetup),
                    child: Text(l10n.welcomeStart),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
