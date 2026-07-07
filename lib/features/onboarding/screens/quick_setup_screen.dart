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
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// 4 eski onboarding ekranını (value-props + questions + name-input) tek
/// ekrana indirger: isim + hedefler + yaş/boy/kilo + aktivite seviyesi +
/// beslenme tercihi + alerjiler + opsiyonel davet kodu. Yaş/boy/kilo/kod
/// dışındaki tüm alanlar opsiyoneldir (boş bırakılabilir).
class QuickSetupScreen extends ConsumerStatefulWidget {
  const QuickSetupScreen({super.key});

  @override
  ConsumerState<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends ConsumerState<QuickSetupScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
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

  static const _activityLevels = ['az_hareketli', 'orta', 'aktif'];
  static const _diets = [
    'yok',
    'vejetaryen',
    'vegan',
    'glutensiz',
    'laktozsuz',
  ];
  static const _allergies = [
    'findik_kabuklu',
    'sut_laktoz',
    'gluten',
    'deniz_urunu',
    'yumurta',
  ];

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

  String _activityLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'az_hareketli':
        return l10n.quickSetupActivitySedentary;
      case 'orta':
        return l10n.quickSetupActivityModerate;
      case 'aktif':
        return l10n.quickSetupActivityActive;
      default:
        return key;
    }
  }

  String _dietLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'yok':
        return l10n.quickSetupDietNone;
      case 'vejetaryen':
        return l10n.quickSetupDietVegetarian;
      case 'vegan':
        return l10n.quickSetupDietVegan;
      case 'glutensiz':
        return l10n.quickSetupDietGlutenFree;
      case 'laktozsuz':
        return l10n.quickSetupDietLactoseFree;
      default:
        return key;
    }
  }

  String _allergyLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'findik_kabuklu':
        return l10n.quickSetupAllergyNuts;
      case 'sut_laktoz':
        return l10n.quickSetupAllergyDairy;
      case 'gluten':
        return l10n.quickSetupAllergyGluten;
      case 'deniz_urunu':
        return l10n.quickSetupAllergySeafood;
      case 'yumurta':
        return l10n.quickSetupAllergyEgg;
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
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _proceed(AppLocalizations l10n) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(userNameProvider.notifier).save(name);

    // Aktivite seviyesi seçilmediyse eski davranış korunur: sessizce 'orta'.
    if (ref.read(onboardingFrequencyProvider) == null) {
      await ref.read(onboardingFrequencyProvider.notifier).select('orta');
    }

    final age = int.tryParse(_ageController.text.trim());
    final height = int.tryParse(_heightController.text.trim());
    final weight = int.tryParse(_weightController.text.trim());
    await ref.read(onboardingAgeProvider.notifier).save(age);
    await ref.read(onboardingHeightProvider.notifier).save(height);
    await ref.read(onboardingWeightProvider.notifier).save(weight);

    final code = _codeController.text.trim();
    if (code.isNotEmpty) {
      await ref.read(referralCodeInputProvider.notifier).save(code);
    }

    // Öneri motorları (öğün/tarif/hareket) için ILND hafızasına kalıcı
    // gerçekler olarak yaz — chat/analiz promptlarına otomatik dahil olur.
    final memory = ref.read(ilndMemoryProvider.notifier);
    if (age != null) await memory.addFact('Yaş: $age');
    if (height != null) await memory.addFact('Boy: $height cm');
    if (weight != null) await memory.addFact('Kilo: $weight kg');
    final diet = ref.read(onboardingDietProvider);
    if (diet != null && diet != 'yok') {
      await memory.addFact('Beslenme tercihi: ${_dietLabel(l10n, diet)}');
    }
    final allergies = ref.read(onboardingAllergiesProvider);
    if (allergies.isNotEmpty) {
      final labels = allergies.map((a) => _allergyLabel(l10n, a)).join(', ');
      await memory.addFact('Alerjiler: $labels');
    }
    final activity = ref.read(onboardingFrequencyProvider);
    if (activity != null) {
      await memory.addFact(
        'Aktivite seviyesi: ${_activityLabel(l10n, activity)}',
      );
    }

    // Önce register'a git, sonra onboarding'i tamamlandı işaretle — router
    // redirect yeniden değerlendirildiğinde aktif konum zaten /register
    // olsun diye (name_input_screen.dart'taki mount-safety deseninin aynısı).
    if (!mounted) return;
    context.go(routeRegister);

    unawaited(AnalyticsService.logOnboardingStepCompleted(1, 'quick_setup'));
    await ref.read(onboardingDoneProvider.notifier).setDone();
  }

  Widget _chipRow(
    AppPalette p, {
    required List<String> keys,
    required bool Function(String key) isSelected,
    required void Function(String key) onTap,
    required String Function(String key) label,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keys.map((key) {
        final on = isSelected(key);
        return Pressable(
          onTap: () => onTap(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: on ? p.accent.withValues(alpha: 0.08) : p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: on ? p.accent : p.textMuted.withValues(alpha: 0.2),
                width: on ? 1.5 : 1,
              ),
            ),
            child: Text(
              label(key),
              style: AppTextStyles.body(
                fontSize: 13,
                color: on ? p.accent : p.text,
              ).copyWith(fontWeight: on ? FontWeight.w600 : FontWeight.normal),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _numberField(AppPalette p, TextEditingController c, String hint) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: AppTextStyles.body(fontSize: 15, color: p.text),
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final goals = ref.watch(onboardingGoalsProvider);
    final activity = ref.watch(onboardingFrequencyProvider);
    final diet = ref.watch(onboardingDietProvider);
    final allergies = ref.watch(onboardingAllergiesProvider);

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
                const SizedBox(height: 32),
                Text(
                  l10n.quickSetupBodyTitle,
                  style: AppTextStyles.heading(fontSize: 18, color: p.text),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.quickSetupBodySubtitle,
                  style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        p,
                        _ageController,
                        l10n.quickSetupAgeHint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _numberField(
                        p,
                        _heightController,
                        l10n.quickSetupHeightHint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _numberField(
                        p,
                        _weightController,
                        l10n.quickSetupWeightHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.quickSetupActivityTitle,
                  style: AppTextStyles.heading(fontSize: 18, color: p.text),
                ),
                const SizedBox(height: 12),
                _chipRow(
                  p,
                  keys: _activityLevels,
                  isSelected: (key) => activity == key,
                  onTap: (key) => ref
                      .read(onboardingFrequencyProvider.notifier)
                      .select(key),
                  label: (key) => _activityLabel(l10n, key),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.quickSetupDietTitle,
                  style: AppTextStyles.heading(fontSize: 18, color: p.text),
                ),
                const SizedBox(height: 12),
                _chipRow(
                  p,
                  keys: _diets,
                  isSelected: (key) => diet == key,
                  onTap: (key) =>
                      ref.read(onboardingDietProvider.notifier).select(key),
                  label: (key) => _dietLabel(l10n, key),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.quickSetupAllergiesTitle,
                  style: AppTextStyles.heading(fontSize: 18, color: p.text),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.quickSetupAllergiesSubtitle,
                  style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
                ),
                const SizedBox(height: 12),
                _chipRow(
                  p,
                  keys: _allergies,
                  isSelected: (key) => allergies.contains(key),
                  onTap: (key) => ref
                      .read(onboardingAllergiesProvider.notifier)
                      .toggle(key),
                  label: (key) => _allergyLabel(l10n, key),
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
                  // AppTheme.dark artık MaterialApp'e bağlı (main.dart) —
                  // ElevatedButtonThemeData zaten aktif moda göre doğru
                  // rengi (disabled dahil) veriyor, manuel override gerekmiyor.
                  child: ElevatedButton(
                    onPressed: _canProceed ? () => _proceed(l10n) : null,
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
