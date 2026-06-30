import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// 4 eski onboarding ekranını (value-props + questions + name-input) tek
/// ekrana indirger: isim + opsiyonel hedef seçimi + opsiyonel davet kodu.
/// Aktivite seviyesi sorusu kaldırıldı, sessizce "Orta aktif" varsayılır.
class QuickSetupScreen extends ConsumerStatefulWidget {
  const QuickSetupScreen({super.key});

  @override
  ConsumerState<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends ConsumerState<QuickSetupScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _canProceed = false;
  bool _showCodeField = false;

  // Internal keys (used for state/toggle logic) — display labels are
  // resolved via l10n in build() through _goalLabel().
  static const _goals = [
    ('kalori_besin_takibi', '🍽️'),
    ('kilo_vermek_almak', '⚖️'),
    ('daha_fazla_hareket', '🏃'),
    ('su_uyku_takibi', '💧'),
    ('aliskanlik_olusturma', '🔄'),
    ('ruh_hali_takibi', '💙'),
  ];

  static const _defaultFrequency = 'Orta aktif';

  String _goalLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'kalori_besin_takibi':
        return l10n.quickSetupGoalCalories;
      case 'kilo_vermek_almak':
        return l10n.quickSetupGoalWeight;
      case 'daha_fazla_hareket':
        return l10n.quickSetupGoalMovement;
      case 'su_uyku_takibi':
        return l10n.quickSetupGoalWaterSleep;
      case 'aliskanlik_olusturma':
        return l10n.quickSetupGoalHabit;
      case 'ruh_hali_takibi':
        return l10n.quickSetupGoalMood;
      default:
        return key;
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      final canProceed = _nameController.text.trim().isNotEmpty;
      if (canProceed != _canProceed) setState(() => _canProceed = canProceed);
    });
    Future.microtask(
      () => ref.read(currentOnboardingStepProvider.notifier).state = (
        1,
        'quick_setup',
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(userNameProvider.notifier).save(name);
    await ref
        .read(onboardingFrequencyProvider.notifier)
        .select(_defaultFrequency);

    final code = _codeController.text.trim();
    if (code.isNotEmpty) {
      await ref.read(referralCodeInputProvider.notifier).save(code);
    }

    // Önce register'a git, sonra onboarding'i tamamlandı işaretle — router
    // redirect yeniden değerlendirildiğinde aktif konum zaten /register
    // olsun diye (name_input_screen.dart'taki mount-safety deseninin aynısı).
    if (!mounted) return;
    context.go(routeRegister);

    unawaited(AnalyticsService.logOnboardingStepCompleted(1, 'quick_setup'));
    await ref.read(onboardingDoneProvider.notifier).setDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final goals = ref.watch(onboardingGoalsProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  l10n.quickSetupTitle,
                  style: AppTextStyles.display(fontSize: 28, color: p.text),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.quickSetupTitleEn,
                  style: AppTextStyles.body(fontSize: 14, color: p.textMuted),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: AppTextStyles.body(
                      fontSize: 16,
                      color: p.text,
                    ).copyWith(fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: l10n.quickSetupNameHint,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.quickSetupGoalsTitle,
                  style: AppTextStyles.heading(fontSize: 18, color: p.text),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.quickSetupGoalsSubtitle,
                  style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _goals.map((item) {
                    final on = goals.contains(item.$1);
                    return Pressable(
                      onTap: () => ref
                          .read(onboardingGoalsProvider.notifier)
                          .toggle(item.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: on
                              ? p.accent.withValues(alpha: 0.08)
                              : p.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: on
                                ? p.accent
                                : p.textMuted.withValues(alpha: 0.2),
                            width: on ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item.$2, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(
                              _goalLabel(l10n, item.$1),
                              style:
                                  AppTextStyles.body(
                                    fontSize: 13,
                                    color: on ? p.accent : p.text,
                                  ).copyWith(
                                    fontWeight: on
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                if (_showCodeField) ...[
                  Text(
                    l10n.quickSetupInviteCodeTitle,
                    style: AppTextStyles.heading(fontSize: 15, color: p.text),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: AppTextStyles.body(fontSize: 15, color: p.text),
                      decoration: InputDecoration(
                        hintText: l10n.quickSetupInviteCodeHint,
                      ),
                    ),
                  ),
                ] else
                  Pressable(
                    onTap: () => setState(() => _showCodeField = true),
                    child: Text(
                      l10n.quickSetupHaveInviteCode,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: p.textMuted,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    // See welcome_screen.dart: ElevatedButtonThemeData is
                    // always light-mode, so the active palette must be
                    // applied explicitly here too.
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.accent,
                      foregroundColor: p.onAccent,
                      disabledBackgroundColor: p.accent.withValues(alpha: 0.3),
                      disabledForegroundColor: p.onAccent.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    onPressed: _canProceed ? _proceed : null,
                    child: Text(l10n.quickSetupContinue),
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
