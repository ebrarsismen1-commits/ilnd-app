import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/primary_button.dart';
import 'package:ilnd_app/features/ekle/food_analysis.dart';
import 'package:ilnd_app/features/ekle/food_analysis_l10n.dart';
import 'package:ilnd_app/features/ekle/ingredient_editor.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Kayıtlı bir öğünün malzemelerini düzeltme sayfası.
///
/// Kural yemek ekleme ekranındakiyle birebir aynı (owner kararı): malzeme
/// eklemek ve çıkarmak BEDAVA, hiçbir AI çağrısı yok — kullanıcı "bunda
/// zeytinyağı da vardı" diyebilmeli ve bu bir düzeltmedir, yeni bir analiz
/// değil. Ücretli olan tek şey makroların yeniden hesaplanması: liste modele
/// gidip yeni kalori/makro geri gelir, o da haftalık analiz hakkından bir
/// tane düşer. Düzeltip hesaplatmayan kullanıcı hiçbir hak harcamaz.
Future<void> showMealEditSheet(BuildContext context, FoodEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.charcoal.withValues(alpha: 0.45),
    isScrollControlled: true,
    builder: (_) => _MealEditSheet(entry: entry),
  );
}

class _MealEditSheet extends ConsumerStatefulWidget {
  const _MealEditSheet({required this.entry});

  final FoodEntry entry;

  @override
  ConsumerState<_MealEditSheet> createState() => _MealEditSheetState();
}

class _MealEditSheetState extends ConsumerState<_MealEditSheet> {
  late List<String> _ingredients = [...widget.entry.malzemeler];

  /// Ekrandaki makroların ait olduğu liste. Kullanıcı listeyi değiştirince
  /// bundan ayrılır ve makrolar "bayat" sayılır.
  late List<String> _computedIngredients = [...widget.entry.malzemeler];

  late int _kalori = widget.entry.kalori;
  late int _protein = widget.entry.protein;
  late int _karbonhidrat = widget.entry.karbonhidrat;
  late int _yag = widget.entry.yag;

  bool _recalculating = false;
  bool _saving = false;

  /// Kayda en son yazılmış liste. Yeniden hesaplama listeyi de yazdığı için
  /// bu, orijinal kaydın değil, son yazmanın halidir.
  late List<String> _savedIngredients = [...widget.entry.malzemeler];

  /// Kaydedilmemiş bir düzeltme var mı.
  bool get _dirty => !listEquals(_ingredients, _savedIngredients);

  /// Makrolar ekrandaki listeyi artık anlatmıyor.
  bool get _macrosStale => !listEquals(_ingredients, _computedIngredients);

  // ── Bedava düzenleme ───────────────────────────────────────────────────────

  void _addIngredient(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    final exists = _ingredients.any(
      (m) => m.toLowerCase() == value.toLowerCase(),
    );
    if (exists) return;
    setState(() => _ingredients = [..._ingredients, value]);
  }

  void _removeIngredient(String value) {
    setState(() => _ingredients = [..._ingredients]..remove(value));
  }

  /// Yalnız listeyi yazar. Makrolar bilerek olduğu gibi kalır.
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(foodRepositoryProvider);
    if (repo == null || _saving) return;
    setState(() => _saving = true);
    try {
      await repo.updateIngredients(widget.entry.id, _ingredients);
      _savedIngredients = [..._ingredients];
      unawaited(AnalyticsService.logFoodEntryEdited(recalculated: false));
      if (!mounted) return;
      IlndToast.success(context, l10n.takipMealUpdated);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      IlndToast.error(context, l10n.takipMealUpdateFailed);
    }
  }

  // ── Ücretli yeniden hesaplama ──────────────────────────────────────────────

  /// Düzeltilmiş listeye göre makroları yeniden tahmin eder ve kaydı günceller.
  ///
  /// Bu ikinci bir analizdir: yerel kapı önce sorulur (kullanıcı boşuna
  /// beklemesin), asıl sınırı yine sunucu uygular.
  Future<void> _recalculate() async {
    final l10n = AppLocalizations.of(context)!;
    if (_recalculating) return;

    if (!ref.read(usageGateProvider).isAllowed(UsageKind.food)) {
      await PaywallScreen.show(
        context,
        reason: l10n.yemekEklePaywallReason,
        source: 'food',
      );
      return;
    }

    setState(() => _recalculating = true);

    // Proxy yapılandırılmamışsa (demo/ön izleme) ağa çıkılmaz: makrolar
    // malzeme sayısıyla orantılı ölçeklenir — yemek ekleme ekranıyla aynı
    // demo güvencesi.
    if (!AppConfig.isAnthropicProxyConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final before = _computedIngredients.length;
      final ratio = before == 0 ? 1.0 : _ingredients.length / before;
      await _applyRecalculated(
        kalori: (_kalori * ratio).round(),
        protein: (_protein * ratio).round(),
        karbonhidrat: (_karbonhidrat * ratio).round(),
        yag: (_yag * ratio).round(),
      );
      return;
    }

    final outcome = await ref
        .read(foodAnalyzerProvider)
        .recalculate(
          yemekAdi: widget.entry.yemekAdi,
          malzemeler: _ingredients,
          idToken: () async =>
              await fb_auth.FirebaseAuth.instance.currentUser?.getIdToken(),
        );

    if (!mounted) return;

    switch (outcome) {
      case FoodAnalysisSuccess(result: final fresh):
        await _applyRecalculated(
          kalori: fresh.kalori,
          protein: fresh.protein.round(),
          karbonhidrat: fresh.karbonhidrat.round(),
          yag: fresh.yag.round(),
        );
      case FoodAnalysisFreeLimit():
        // Hak başka bir cihazda harcanmış olabilir: son sözü sunucu söyler.
        unawaited(AnalyticsService.logFreeLimitReached(UsageKind.food.name));
        ref.read(usageGateProvider).markExhausted(UsageKind.food);
        setState(() => _recalculating = false);
        if (!mounted) return;
        await PaywallScreen.show(
          context,
          reason: l10n.yemekEklePaywallReason,
          source: 'food',
        );
      case FoodAnalysisFailure(:final code):
        unawaited(AnalyticsService.logFoodAnalysisFailed(code.name));
        setState(() => _recalculating = false);
        // Düzeltme ekranda kalır: bir ağ hatası kullanıcının yazdığı listeyi
        // silmemeli.
        IlndToast.error(context, outcome.localized(l10n));
    }
  }

  /// Yeni makroları kayda yazar, ekranı tazeler ve hakkı düşer.
  Future<void> _applyRecalculated({
    required int kalori,
    required int protein,
    required int karbonhidrat,
    required int yag,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(foodRepositoryProvider);
    try {
      await repo?.updateAfterRecalculate(
        widget.entry.id,
        malzemeler: _ingredients,
        kalori: kalori,
        protein: protein,
        karbonhidrat: karbonhidrat,
        yag: yag,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _recalculating = false);
      IlndToast.error(context, l10n.takipMealUpdateFailed);
      return;
    }
    // Hak, çağrı sunucuda gerçekleştiği için yazma başarısız olsa bile
    // harcanmış olurdu; sayaç yalnız çağrı yapıldığında ilerler.
    ref.read(usageGateProvider).record(UsageKind.food);
    unawaited(AnalyticsService.logFoodEntryEdited(recalculated: true));
    if (!mounted) return;
    setState(() {
      _kalori = kalori;
      _protein = protein;
      _karbonhidrat = karbonhidrat;
      _yag = yag;
      _computedIngredients = [..._ingredients];
      _savedIngredients = [..._ingredients];
      _recalculating = false;
    });
    IlndToast.success(context, l10n.takipMealUpdated);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: p.base,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            12,
            AppSpacing.screenPadding,
            28,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text(
                  l10n.takipMealEditTitle,
                  style: AppTextStyles.sectionLabel(color: p.accent),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.entry.yemekAdi,
                  style: AppTextStyles.display(fontSize: 24, color: p.text),
                ),
                const SizedBox(height: 6),

                // Sayılar hep görünür: düzeltmenin makroları değiştirmediği
                // ancak ikisi yan yana dururken anlaşılır.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      l10n.takipKcal(_kalori),
                      style: AppTextStyles.mono(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.takipMacroSummary(_protein, _karbonhidrat, _yag),
                        style: AppTextStyles.body(
                          fontSize: 11.5,
                          color: p.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  l10n.takipMealEditFreeHint,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: p.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                IngredientEditor(
                  ingredients: _ingredients,
                  onAdd: _addIngredient,
                  onRemove: _removeIngredient,
                  onRecalculate: _recalculate,
                  macrosStale: _macrosStale,
                  recalculating: _recalculating,
                  p: p,
                  l10n: l10n,
                ),

                if (_dirty && !_recalculating) ...[
                  const SizedBox(height: 20),
                  PrimaryButton(
                    icon: Icons.check_rounded,
                    label: l10n.takipMealEditSave,
                    onTap: _save,
                    p: p,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
