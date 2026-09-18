import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/onboarding/profile_sync.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Onboarding'de verilen bilgilerin sonradan düzenlendiği ekran.
///
/// Bu ekran yoktu: kullanıcı kilosunu yanlış girdiyse ya da vegan olduysa
/// değiştirmenin hiçbir yolu yoktu. Alerji listesi tarif önerisini beslediği
/// için bunun bir güvenlik tarafı da var.
///
/// Kaydetme [ProfileHydrationNotifier.pushLocalProfile] üzerinden gider:
/// değişiklik hem Firestore profiline hem ILND'nin "bilinen gerçekler"
/// hafızasına yazılır. Yalnız birine yazmak, ILND'nin eski kiloyu bilmeye
/// devam etmesi demek olurdu.
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  // Anahtarlar quick_setup_screen.dart'takilerle BİREBİR aynı olmalı: aynı
  // depoya yazıyorlar ve daily_read.dart hedefleri bu anahtarlarla eşliyor.
  static const _goals = [
    'kalori_besin_takibi',
    'kilo_vermek_almak',
    'daha_fazla_hareket',
    'su_uyku_takibi',
    'aliskanlik_olusturma',
    'ruh_hali_takibi',
  ];
  static const _activityLevels = ['az_hareketli', 'orta', 'aktif'];
  static const _diets = [
    'yok',
    'vejetaryen',
    'vegan',
    'glutensiz',
    'laktozsuz',
  ];
  static const _allergies = ['kuruyemis', 'sut', 'gluten', 'deniz', 'yumurta'];

  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(userNameProvider));
    _age = TextEditingController(
      text: ref.read(onboardingAgeProvider)?.toString() ?? '',
    );
    _height = TextEditingController(
      text: ref.read(onboardingHeightProvider)?.toString() ?? '',
    );
    _weight = TextEditingController(
      text: ref.read(onboardingWeightProvider)?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Boş bırakılan sayı alanı "bilinmiyor" demektir, sıfır değil.
  int? _parse(TextEditingController c) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Future<void> _save(AppLocalizations l10n) async {
    setState(() => _saving = true);
    try {
      final name = _name.text.trim();
      if (name.isNotEmpty) {
        await ref.read(userNameProvider.notifier).save(name);
      }
      await ref.read(onboardingAgeProvider.notifier).save(_parse(_age));
      await ref.read(onboardingHeightProvider.notifier).save(_parse(_height));
      await ref.read(onboardingWeightProvider.notifier).save(_parse(_weight));

      // Sunucu + ILND hafızası tek çağrıda güncellenir.
      await ref.read(profileHydrationProvider.notifier).pushLocalProfile();

      if (!mounted) return;
      IlndToast.success(context, l10n.preferencesSaved);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) IlndToast.error(context, l10n.preferencesSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 16, 4),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 18,
                        color: p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Expanded şart: "tercihler" diğer ekran adlarından uzun
                  // ve 30 puntoda dar cihazda geri okuyla yan yana sığmıyor
                  // (320px'te taştı).
                  Expanded(
                    child: Text(
                      l10n.preferencesTitle,
                      style: AppTextStyles.screenTitle(color: p.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  8,
                  AppSpacing.screenPadding,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(l10n.preferencesNameLabel, p: p),
                    const SizedBox(height: 8),
                    _TextField(
                      controller: _name,
                      hint: l10n.quickSetupNameHint,
                      p: p,
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    _Label(l10n.preferencesGoalsLabel, p: p),
                    const SizedBox(height: 4),
                    _Help(l10n.preferencesGoalsHelp, p: p),
                    const SizedBox(height: 10),
                    _Chips(
                      keys: _goals,
                      isOn: goals.contains,
                      onTap: (k) =>
                          ref.read(onboardingGoalsProvider.notifier).toggle(k),
                      label: (k) => _goalLabel(l10n, k),
                      p: p,
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    _Label(l10n.preferencesBodyLabel, p: p),
                    const SizedBox(height: 8),
                    // Üç alan dar ekranda yan yana sığmıyor (320px'te 11px
                    // taşıyordu). Dar cihazda alt alta inerler; kural #14'ün
                    // sınıfı, sabit boyut varsaymak.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fields = [
                          (_age, l10n.quickSetupAgeHint),
                          (_height, l10n.quickSetupHeightHint),
                          (_weight, l10n.quickSetupWeightHint),
                        ];
                        if (constraints.maxWidth < 300) {
                          return Column(
                            children: [
                              for (final (c, hint) in fields) ...[
                                _TextField(
                                  controller: c,
                                  hint: hint,
                                  number: true,
                                  p: p,
                                ),
                                if (c != fields.last.$1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            for (final (c, hint) in fields) ...[
                              Expanded(
                                child: _TextField(
                                  controller: c,
                                  hint: hint,
                                  number: true,
                                  p: p,
                                ),
                              ),
                              if (c != fields.last.$1)
                                const SizedBox(width: 10),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    _Label(l10n.preferencesActivityLabel, p: p),
                    const SizedBox(height: 10),
                    _Chips(
                      keys: _activityLevels,
                      isOn: (k) => activity == k,
                      onTap: (k) => ref
                          .read(onboardingFrequencyProvider.notifier)
                          .select(k),
                      label: (k) => _activityLabel(l10n, k),
                      p: p,
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    _Label(l10n.preferencesDietLabel, p: p),
                    const SizedBox(height: 10),
                    _Chips(
                      keys: _diets,
                      isOn: (k) => diet == k,
                      onTap: (k) =>
                          ref.read(onboardingDietProvider.notifier).select(k),
                      label: (k) => _dietLabel(l10n, k),
                      p: p,
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),

                    _Label(l10n.preferencesAllergiesLabel, p: p),
                    const SizedBox(height: 4),
                    _Help(l10n.preferencesAllergiesHelp, p: p),
                    const SizedBox(height: 10),
                    _Chips(
                      keys: _allergies,
                      isOn: allergies.contains,
                      onTap: (k) => ref
                          .read(onboardingAllergiesProvider.notifier)
                          .toggle(k),
                      label: (k) => _allergyLabel(l10n, k),
                      p: p,
                    ),
                    const SizedBox(height: 28),

                    Pressable(
                      onTap: _saving ? null : () => _save(l10n),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _saving ? p.accentSoft : p.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _saving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: p.onAccent,
                                ),
                              )
                            : Text(
                                l10n.preferencesSave,
                                style: AppTextStyles.body(
                                  fontSize: 15,
                                  color: p.onAccent,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Etiket çözümleri quick_setup_screen ile aynı anahtarları kullanır.
  String _goalLabel(AppLocalizations l10n, String key) => switch (key) {
    'kalori_besin_takibi' => l10n.quickSetupGoalCalories,
    'kilo_vermek_almak' => l10n.quickSetupGoalWeight,
    'daha_fazla_hareket' => l10n.quickSetupGoalMovement,
    'su_uyku_takibi' => l10n.quickSetupGoalWaterSleep,
    'aliskanlik_olusturma' => l10n.quickSetupGoalHabit,
    _ => l10n.quickSetupGoalMood,
  };

  String _activityLabel(AppLocalizations l10n, String key) => switch (key) {
    'az_hareketli' => l10n.quickSetupActivitySedentary,
    'orta' => l10n.quickSetupActivityModerate,
    _ => l10n.quickSetupActivityActive,
  };

  String _dietLabel(AppLocalizations l10n, String key) => switch (key) {
    'yok' => l10n.quickSetupDietNone,
    'vejetaryen' => l10n.quickSetupDietVegetarian,
    'vegan' => l10n.quickSetupDietVegan,
    'glutensiz' => l10n.quickSetupDietGlutenFree,
    _ => l10n.quickSetupDietLactoseFree,
  };

  String _allergyLabel(AppLocalizations l10n, String key) => switch (key) {
    'kuruyemis' => l10n.quickSetupAllergyNuts,
    'sut' => l10n.quickSetupAllergyDairy,
    'gluten' => l10n.quickSetupAllergyGluten,
    'deniz' => l10n.quickSetupAllergySeafood,
    _ => l10n.quickSetupAllergyEgg,
  };
}

// ─── Parçalar ────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.p});
  final String text;
  final AppPalette p;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.sectionLabel(color: p.accent));
}

class _Help extends StatelessWidget {
  const _Help(this.text, {required this.p});
  final String text;
  final AppPalette p;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.body(fontSize: 11.5, color: p.textMuted));
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    required this.p,
    this.number = false,
  });

  final TextEditingController controller;
  final String hint;
  final AppPalette p;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        // Sayı alanına harf girilmesini baştan engelle: boş bırakmak
        // "bilinmiyor" demek, ama "abc" hiçbir şey demek değil.
        inputFormatters: number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: AppTextStyles.body(fontSize: 15, color: p.text),
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.keys,
    required this.isOn,
    required this.onTap,
    required this.label,
    required this.p,
  });

  final List<String> keys;
  final bool Function(String key) isOn;
  final void Function(String key) onTap;
  final String Function(String key) label;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keys.map((key) {
        final on = isOn(key);
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
}
