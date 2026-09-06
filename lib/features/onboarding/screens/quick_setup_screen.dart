import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/motion.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Kurulumun adımları. Sıra bilerek şu: önce isim (tek zorunlu alan ve
/// ekranı kişiselleştiren şey), sonra niyet, sonra sayılar, en sonda
/// beslenme. Ağırlaşan sorular sona bırakılır.
enum _SetupStep {
  name('quick_setup_name'),
  goals('quick_setup_goals'),
  body('quick_setup_body'),
  food('quick_setup_food');

  const _SetupStep(this.analyticsName);

  /// Terk/tamamlama olaylarında bu adımı temsil eden ad.
  final String analyticsName;
}

/// Kurulum: isim + hedefler + yaş/boy/kilo + aktivite + beslenme tercihi +
/// alerjiler + opsiyonel davet kodu.
///
/// Eskiden dört ekran vardı, sonra hepsi TEK bir uzun sayfaya indirildi. Tek
/// sayfa da kendi sorununu getirdi: yeni kullanıcı, daha hiçbir şey görmediği
/// uygulamada yedi alan grubu birden görüyordu ve ilk izlenim "form doldur"
/// oluyordu. Artık aynı alanlar dört adıma bölünmüş durumda — sorular aynı,
/// bir seferde görünen yük daha az.
///
/// Zorunluluk kuralı değişmedi: yalnız isim zorunlu. Kalan üç adım tek tek
/// geçilebilir, çünkü hiçbiri ürünün çalışması için şart değil; hepsi
/// önerileri kişiselleştiriyor.
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

  /// Görünen adım.
  _SetupStep _step = _SetupStep.name;

  // Internal keys (used for state/toggle logic) — display labels are
  // resolved via l10n in build() through _goalLabel().
  static const _goals = [
    ('kalori_besin_takibi', Icons.restaurant_rounded),
    ('kilo_vermek_almak', Icons.monitor_weight_outlined),
    ('daha_fazla_hareket', Icons.directions_run_rounded),
    ('su_uyku_takibi', Icons.water_drop_rounded),
    ('aliskanlik_olusturma', Icons.autorenew_rounded),
    ('ruh_hali_takibi', Icons.favorite_border_rounded),
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
    _restore();
    _nameController.addListener(() {
      final canProceed = _nameController.text.trim().isNotEmpty;
      if (canProceed != _canProceed) setState(() => _canProceed = canProceed);
    });
    Future.microtask(_markStep);
  }

  /// Yarıda bırakılan kurulumu kaldığı yerden açar.
  ///
  /// Cevaplar zaten diskteydi (çipler seçildikleri anda yazılıyor, isim ve
  /// sayılar adım geçilirken) ama ADIM ekranın kendi state'indeydi: uygulama
  /// kapanınca kullanıcı en baştan başlıyor, verdiği bütün cevapları
  /// yeniden geçmek zorunda kalıyordu.
  ///
  /// İsim boşken kayıtlı adıma dönmek YASAK: zorunluluk kapısı yalnız ilk
  /// adımda sorulduğu için kullanıcı isimsiz halde son adıma düşer, "hazırım"
  /// dediğinde [_proceed] sessizce geri döner ve düğme hiçbir şey yapmaz.
  void _restore() {
    _nameController.text = ref.read(userNameProvider);
    final age = ref.read(onboardingAgeProvider);
    final height = ref.read(onboardingHeightProvider);
    final weight = ref.read(onboardingWeightProvider);
    if (age != null) _ageController.text = '$age';
    if (height != null) _heightController.text = '$height';
    if (weight != null) _weightController.text = '$weight';
    _canProceed = _nameController.text.trim().isNotEmpty;

    final saved = ref.read(quickSetupStepProvider);
    if (saved <= 0 || saved >= _SetupStep.values.length || !_canProceed) return;
    _step = _SetupStep.values[saved];
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

  // ── Adım gezinmesi ─────────────────────────────────────────────────────────

  /// Terk edilme olayı hangi adımda olduğumuzu bilsin diye her geçişte
  /// güncellenir (bkz. [currentOnboardingStepProvider], main.dart).
  ///
  /// Adım indeksi kurulumun İÇİNDEKİ sıradır (1-4); ekranlar arası sıra
  /// (karşılama 0, ilk giriş 2) ada bakılarak ayrılır.
  void _markStep() {
    if (!mounted) return;
    ref.read(currentOnboardingStepProvider.notifier).state = (
      _step.index + 1,
      _step.analyticsName,
    );
  }

  /// Bir sonraki adım. Son adımdaysa kurulumu bitirir.
  ///
  /// Geçilen adım tamamlanmış sayılır: huni ancak her adımın kendi olayı
  /// varsa kurulabiliyor, tek sabit çağrı yalnız "kurulumu bitirenler"i
  /// gösteriyordu (ANALITIK_SOZLUGU notu).
  Future<void> _next(AppLocalizations l10n) async {
    if (_step == _SetupStep.name && !_canProceed) return;
    unawaited(
      AnalyticsService.logOnboardingStepCompleted(
        _step.index + 1,
        _step.analyticsName,
      ),
    );
    // Adımın kendi alanları geçilirken yazılır: kurulum yarıda kalırsa
    // kullanıcı yalnız adımı değil cevaplarını da geri bulsun.
    await _persistStepInput();

    final next = _step.index + 1;
    if (next >= _SetupStep.values.length) {
      await _proceed(l10n);
      return;
    }
    if (!mounted) return;
    // Klavye bir sonraki adımın üstünde asılı kalmasın.
    FocusScope.of(context).unfocus();
    setState(() => _step = _SetupStep.values[next]);
    _markStep();
    await ref.read(quickSetupStepProvider.notifier).save(next);
  }

  /// Görünen adımın metin alanlarını diske yazar. Çipler (hedef, aktivite,
  /// beslenme, alerji) zaten seçildikleri anda yazılıyor.
  Future<void> _persistStepInput() async {
    switch (_step) {
      case _SetupStep.name:
        await ref
            .read(userNameProvider.notifier)
            .save(_nameController.text.trim());
      case _SetupStep.body:
        await ref
            .read(onboardingAgeProvider.notifier)
            .save(int.tryParse(_ageController.text.trim()));
        await ref
            .read(onboardingHeightProvider.notifier)
            .save(int.tryParse(_heightController.text.trim()));
        await ref
            .read(onboardingWeightProvider.notifier)
            .save(int.tryParse(_weightController.text.trim()));
      case _SetupStep.goals:
      case _SetupStep.food:
        break;
    }
  }

  void _back() {
    if (_step.index == 0) return;
    FocusScope.of(context).unfocus();
    final previous = _step.index - 1;
    setState(() => _step = _SetupStep.values[previous]);
    _markStep();
    unawaited(ref.read(quickSetupStepProvider.notifier).save(previous));
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
    // Yarım kalmış adım bir sonraki kuruluma sarkmasın.
    await ref.read(quickSetupStepProvider.notifier).clear();

    if (!mounted) return;
    context.go(routeRegister);

    await ref.read(onboardingDoneProvider.notifier).setDone();
  }

  // ── Parçalar ───────────────────────────────────────────────────────────────

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

  /// Adım başlığı: büyük satır + varsa açıklama. Her adımın kendi tek büyük
  /// anı olur, alt başlık onu açar.
  Widget _stepHeading(
    AppPalette p, {
    required String title,
    String? subtitle,
    String? secondaryTitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.display(fontSize: 28, color: p.text)),
        // Bkz. welcome_screen: iki dilli başlık yalnız Türkçede. Boşluk da
        // koşula dahil, yoksa İngilizcede sarkan bir aralık kalır.
        if (secondaryTitle != null) ...[
          const SizedBox(height: 6),
          Text(
            secondaryTitle,
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.body(
              fontSize: 13,
              color: p.textMuted,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// İlerleme çizgisi: adım başına bir dilim. Sayı da veriliyor, çünkü çizgi
  /// "ne kadar kaldı" sorusunu yaklaşık, sayı kesin cevaplıyor.
  Widget _progress(AppPalette p, AppLocalizations l10n) {
    final total = _SetupStep.values.length;
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: _step.index == 0
              ? null
              : Semantics(
                  button: true,
                  label: l10n.quickSetupBack,
                  child: Pressable(
                    onTap: _back,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 26,
                      color: p.textMuted,
                    ),
                  ),
                ),
        ),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: i <= _step.index ? p.accent : p.border,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          l10n.quickSetupStepCounter(_step.index + 1, total),
          style: AppTextStyles.mono(fontSize: 11, color: p.textMuted),
        ),
      ],
    );
  }

  // ── Adım gövdeleri ─────────────────────────────────────────────────────────

  Widget _nameStep(AppPalette p, AppLocalizations l10n) {
    return Column(
      key: const ValueKey(_SetupStep.name),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
          p,
          title: l10n.quickSetupTitle,
          secondaryTitle: l10n.localeName.startsWith('tr')
              ? l10n.quickSetupTitleEn
              : null,
        ),
        SizedBox(
          height: 52,
          child: TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(l10n),
            style: AppTextStyles.body(
              fontSize: 15,
              color: p.text,
            ).copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(hintText: l10n.quickSetupNameHint),
          ),
        ),
      ],
    );
  }

  Widget _goalsStep(AppPalette p, AppLocalizations l10n) {
    final goals = ref.watch(onboardingGoalsProvider);
    return Column(
      key: const ValueKey(_SetupStep.goals),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
          p,
          title: l10n.quickSetupGoalsTitle,
          subtitle: l10n.quickSetupGoalsSubtitle,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _goals.map((item) {
            final on = goals.contains(item.$1);
            return Pressable(
              onTap: () =>
                  ref.read(onboardingGoalsProvider.notifier).toggle(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: on ? p.accent.withValues(alpha: 0.08) : p.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: on ? p.accent : p.textMuted.withValues(alpha: 0.2),
                    width: on ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$2, size: 16, color: on ? p.accent : p.textMuted),
                    const SizedBox(width: 6),
                    // İkonun yanındaki etiket esner: dar ekranda ya da
                    // büyütülmüş yazı tipinde "kalori/besin takibi" çipi
                    // satırı taşırıyordu.
                    Flexible(
                      child: Text(
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
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _bodyStep(AppPalette p, AppLocalizations l10n) {
    final activity = ref.watch(onboardingFrequencyProvider);
    return Column(
      key: const ValueKey(_SetupStep.body),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
          p,
          title: l10n.quickSetupBodyTitle,
          subtitle: l10n.quickSetupBodySubtitle,
        ),
        // Üç alan yan yana ancak yeterli genişlik varsa durur. 375dp'lik
        // yaygın telefonda her alana ~100dp düşüyor ve ipucu metni
        // kırpılıyordu: kullanıcı "boy (..." görüp santim mi kilo mu
        // istendiğini okuyamıyordu. Dar cihazda alt alta inerler.
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              (_ageController, l10n.quickSetupAgeHint),
              (_heightController, l10n.quickSetupHeightHint),
              (_weightController, l10n.quickSetupWeightHint),
            ];
            if (constraints.maxWidth < 330) {
              return Column(
                children: [
                  for (final (c, hint) in fields) ...[
                    _numberField(p, c, hint),
                    if (c != fields.last.$1) const SizedBox(height: 10),
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (final (c, hint) in fields) ...[
                  Expanded(child: _numberField(p, c, hint)),
                  if (c != fields.last.$1) const SizedBox(width: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          l10n.quickSetupActivityTitle,
          style: AppTextStyles.heading(fontSize: 19, color: p.text),
        ),
        const SizedBox(height: 12),
        _chipRow(
          p,
          keys: _activityLevels,
          isSelected: (key) => activity == key,
          onTap: (key) =>
              ref.read(onboardingFrequencyProvider.notifier).select(key),
          label: (key) => _activityLabel(l10n, key),
        ),
      ],
    );
  }

  Widget _foodStep(AppPalette p, AppLocalizations l10n) {
    final diet = ref.watch(onboardingDietProvider);
    final allergies = ref.watch(onboardingAllergiesProvider);
    return Column(
      key: const ValueKey(_SetupStep.food),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(p, title: l10n.quickSetupDietTitle),
        _chipRow(
          p,
          keys: _diets,
          isSelected: (key) => diet == key,
          onTap: (key) => ref.read(onboardingDietProvider.notifier).select(key),
          label: (key) => _dietLabel(l10n, key),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.quickSetupAllergiesTitle,
          style: AppTextStyles.heading(fontSize: 19, color: p.text),
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
          onTap: (key) =>
              ref.read(onboardingAllergiesProvider.notifier).toggle(key),
          label: (key) => _allergyLabel(l10n, key),
        ),
        const SizedBox(height: 28),
        // Davet kodu son adımda: kodu olan azınlık, herkesin önüne bir alan
        // daha koymaya değmiyor.
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
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final isLast = _step.index == _SetupStep.values.length - 1;
    // Yalnız isim zorunlu; kalan adımlar boş bırakılabilir.
    final canAdvance = _step != _SetupStep.name || _canProceed;

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _progress(p, l10n),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: motionDuration(
                      context,
                      full: const Duration(milliseconds: 320),
                    ),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeOut,
                    // Adımlar aynı yükseklikte değil: geçişte iki gövde
                    // üst üste ölçülmesin diye yalnız gelen çizilir.
                    layoutBuilder: (current, previous) =>
                        current ?? const SizedBox.shrink(),
                    child: switch (_step) {
                      _SetupStep.name => _nameStep(p, l10n),
                      _SetupStep.goals => _goalsStep(p, l10n),
                      _SetupStep.body => _bodyStep(p, l10n),
                      _SetupStep.food => _foodStep(p, l10n),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                // AppTheme.dark artık MaterialApp'e bağlı (main.dart) —
                // ElevatedButtonThemeData zaten aktif moda göre doğru
                // rengi (disabled dahil) veriyor, manuel override gerekmiyor.
                child: ElevatedButton(
                  onPressed: canAdvance ? () => _next(l10n) : null,
                  child: Text(
                    isLast ? l10n.quickSetupFinish : l10n.quickSetupContinue,
                  ),
                ),
              ),
              // Geçme kapısı yalnız ORTA adımlarda. İsim adımında "geç"
              // göstermek zorunlu olan tek alanı isteğe bağlıymış gibi
              // gösterirdi; son adımda ise "hazırım" ile birebir aynı işi
              // yapan ikinci bir düğme olurdu (ekranda iki kapı, tek yol).
              SizedBox(
                height: 44,
                child: _step == _SetupStep.name || isLast
                    ? null
                    : Center(
                        child: Semantics(
                          button: true,
                          child: Pressable(
                            onTap: () => _next(l10n),
                            child: Text(
                              l10n.quickSetupSkipStep,
                              style: AppTextStyles.body(
                                fontSize: 13,
                                color: p.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
