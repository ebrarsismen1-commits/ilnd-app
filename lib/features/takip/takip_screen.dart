import 'package:flutter/material.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/confirm_delete.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/takip/meal_edit_sheet.dart';
import 'package:ilnd_app/features/takip/takip_day.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

// ─── Statik hedefler (ileride kullanıcıya göre ayarlanacak) ──────────────────

const _kKaloriHedef = 2000;
const _kProteinHedef = 130;
const _kKarbHedef = 250;
const _kYagHedef = 70;
const _kSuHedef = 2000; // ml

// ─── Screen ──────────────────────────────────────────────────────────────────

/// Takip bloğu — makro halkası, öğünler, aktivite ve alışkanlıklar.
///
/// Ayrı bir "Takip" ekranı YOKTUR: bu blok doğrudan Bugün ekranında yaşar.
/// Gerekçe: kullanıcının kendi ürettiği veri (öğün, su, alışkanlık) ürünün
/// günlük merkezidir; ayrı bir sekmenin ya da push edilen bir ekranın
/// arkasında durduğu sürece pratikte görünmüyordu. [startIndex] ana ekrandaki
/// giriş animasyonu sırasını bozmamak için dışarıdan verilir.
/// Takip kendi ekrani (tasarim handoff §6). d18f43e'de Bugun'un icine
/// gomulmustu; owner karariyla tekrar ayri ekran oldu — Bugun'daki sessiz
/// "takip" satirindan ve Sen'deki ayarlar listesinden acilir.
class TakipScreen extends ConsumerWidget {
  const TakipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10, bottom: 4),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 26,
                        color: p.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    l10n.takipTitle,
                    style: AppTextStyles.screenTitle(
                      color: p.text,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const TakipSections(),
            ],
          ),
        ),
      ),
    );
  }
}

class TakipSections extends ConsumerWidget {
  const TakipSections({super.key, this.startIndex = 0});

  final int startIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Gezgin en üstte: altındaki her bölüm "hangi gün" sorusunun
        // cevabına bağlı, o yüzden soru önce sorulur.
        Entrance(
          index: startIndex,
          child: _DayNavigator(p: p, l10n: l10n),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Entrance(
          index: startIndex + 1,
          child: _MacroCard(p: p, l10n: l10n),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Entrance(
          index: startIndex + 2,
          child: _MealsSection(p: p, l10n: l10n),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Entrance(
          index: startIndex + 3,
          child: _ActivitySection(p: p, l10n: l10n),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Entrance(
          index: startIndex + 4,
          child: _HabitsSection(p: p, l10n: l10n),
        ),
      ],
    );
  }
}

// ─── SECTION 0: Gün gezgini ──────────────────────────────────────────────────

/// Takip ekranının "hangi gün" ekseni.
///
/// Ekran bugüne çakılıydı: dün ne yediğini görmek isteyenin hiçbir kapısı
/// yoktu. Geçmişi ayrı bir ekrana koymak yerine gezgin seçildi (owner
/// kararı) — aynı ekran, tek eksende geriye gider. Takvim ızgarası
/// açılmıyor: kullanıcı pratikte bir-iki gün geriye bakar, daha uzağı zaten
/// alışkanlık ızgarasının hafta/ay penceresi anlatır.
///
/// İleri gitmek yok: yaşanmamış günün kaydı da yok, o yüzden bugüne
/// geldiğinde sağ ok sessizce sönümlenir (kaybolmaz — kaybolan bir düğme
/// düzeni oynatır).
class _DayNavigator extends ConsumerWidget {
  const _DayNavigator({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final isToday = ref.watch(isTodaySelectedProvider);
    final now = DateTime.now();
    final isYesterday =
        dayKey(day) == dayKey(DateTime(now.year, now.month, now.day - 1));

    // Dün ve bugünün adı var; ötesi tarihtir. Alt satır her zaman tam
    // tarihi verir, yoksa "dün"e bakan kullanıcı hangi güne baktığını
    // ekranda hiçbir yerde göremiyordu.
    final label = isToday
        ? l10n.takipDayToday
        : isYesterday
        ? l10n.takipDayYesterday
        : DateFormat('d MMMM', l10n.localeName).format(day);
    final fullDate = DateFormat(
      'EEEE · d MMMM',
      l10n.localeName,
    ).format(day).toUpperCase();

    // Gün aritmetiği Duration ile değil takvimle yapılır: yaz saati geçişinde
    // 24 saat eklemek aynı güne geri düşebiliyor.
    void go(int delta) => ref.read(selectedDayProvider.notifier).state =
        DateTime(day.year, day.month, day.day + delta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _DayArrow(
              icon: Icons.chevron_left_rounded,
              label: l10n.takipDayPrev,
              onTap: () => go(-1),
              p: p,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    label,
                    style: AppTextStyles.display(fontSize: 22, color: p.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fullDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label(
                      fontSize: 10,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            _DayArrow(
              icon: Icons.chevron_right_rounded,
              label: l10n.takipDayNext,
              onTap: isToday ? null : () => go(1),
              p: p,
            ),
          ],
        ),
        if (!isToday) ...[
          const SizedBox(height: 12),
          Text(
            l10n.takipPastDayNotice,
            style: AppTextStyles.body(
              fontSize: 11.5,
              color: p.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            child: Pressable(
              onTap: () => ref.read(selectedDayProvider.notifier).state =
                  startOfDay(DateTime.now()),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  l10n.takipBackToToday,
                  style: AppTextStyles.label(fontSize: 11, color: p.accent),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 44px'lik dokunma hedefi: ok işaretinin kendisi 26px, gerisi boşluk.
class _DayArrow extends StatelessWidget {
  const _DayArrow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.p,
  });

  final IconData icon;
  final String label;

  /// null ise ok sönümlenir ve dokunmaz (bugünden ileri gidilmez).
  final VoidCallback? onTap;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 26, color: enabled ? p.text : p.border),
        ),
      ),
    );
  }
}

// ─── Shared card wrapper ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.p});
  final Widget child;
  final AppPalette p;

  static const padding = EdgeInsets.all(AppSpacing.cardPadding);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: child,
    );
  }
}

/// 0.5px ayırıcı — bölüm içi satırları kart yerine bu ayırır.
class _Hairline extends StatelessWidget {
  const _Hairline({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) => Container(height: 0.5, color: p.border);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: AppTextStyles.sectionLabel(color: color)),
    );
  }
}

// ─── SECTION 1: Makro — tek büyük sayı ────────────────────────────────────────

/// Donut grafiği kaldırıldı (handoff §6, DESIGN_SYSTEM §7.2 "ölçek zıtlığı"):
/// üç dilimli bir çember, üç sayının hangisinin önemli olduğunu söylemiyordu.
/// Ekranın kahramanı artık tek bir sayı — seçili günün kalorisi.
class _MacroCard extends ConsumerWidget {
  const _MacroCard({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = ref.watch(selectedDayMacrosProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l10n.takipMacrosLabel, color: p.accent),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${macros.kalori}',
              style: AppTextStyles.mono(
                fontSize: 56,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
            const SizedBox(width: 8),
            // Hedef etiketi esner: kahraman sayı büyüdükçe (dört haneli
            // kalori, dar ekran) sabit genişlikte kalırsa satır taşıyor.
            Flexible(
              child: Text(
                '/ $_kKaloriHedef kcal',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mono(fontSize: 13, color: p.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _MacroBar(
          label: l10n.takipProtein,
          current: macros.protein,
          goal: _kProteinHedef,
          color: p.accent,
          p: p,
        ),
        _MacroBar(
          label: l10n.takipCarbs,
          current: macros.karbonhidrat,
          goal: _kKarbHedef,
          color: p.amber,
          p: p,
        ),
        _MacroBar(
          label: l10n.takipFat,
          current: macros.yag,
          goal: _kYagHedef,
          color: p.textMuted,
          p: p,
        ),
      ],
    );
  }
}

/// Etiket + değer, altında 3px'lik ince bar. Bar bir grafik değil, bir
/// ölçü çizgisi: dolgu yüzdesi hedefin neresinde olduğunu tek bakışta verir.
class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
    required this.p,
  });
  final String label;
  final int current;
  final int goal;
  final Color color;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final ratio = goal <= 0 ? 0.0 : (current / goal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body(fontSize: 12.5, color: p.textMuted),
                ),
              ),
              Text(
                '${current}g / ${goal}g',
                style: AppTextStyles.mono(fontSize: 12.5, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 3,
              backgroundColor: p.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SECTION 2: Meals ─────────────────────────────────────────────────────────

class _MealsSection extends ConsumerWidget {
  const _MealsSection({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(selectedDayEntriesProvider);
    final entries = entriesAsync.valueOrNull ?? [];
    final isToday = ref.watch(isTodaySelectedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l10n.takipMealsLabel, color: p.textMuted),
        // Kart yok: satırları 0.5px hairline ayırır (handoff §6).
        Column(
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  // Boş bugün bir davet, boş geçmiş gün bir kayıt: aynı
                  // cümle ikisini de anlatmıyor.
                  isToday ? l10n.takipNoMealsYet : l10n.takipNoMealsThatDay,
                  style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
                ),
              )
            else
              ...entries.asMap().entries.map((e) {
                final isLast = e.key == entries.length - 1;
                return Column(
                  children: [
                    _FoodEntryRow(
                      entry: e.value,
                      // Kayıtlı öğün her günde düzeltilebilir: düzeltme
                      // geçmişi değiştirmek değil, yanlış yazılmışı
                      // doğrultmaktır.
                      onTap: () => showMealEditSheet(context, e.value),
                      p: p,
                      l10n: l10n,
                    ),
                    if (!isLast || isToday) _Hairline(p: p),
                  ],
                );
              }),
            // Geçmiş güne öğün EKLENMEZ: eklenen kayıt bugünün saatiyle
            // yazılırdı ve kullanıcı baktığı güne düştüğünü sanırdı.
            if (isToday) ...[
              if (entries.isEmpty) _Hairline(p: p),
              _AddMealRow(p: p, l10n: l10n),
            ],
          ],
        ),
      ],
    );
  }
}

class _FoodEntryRow extends StatelessWidget {
  const _FoodEntryRow({
    required this.entry,
    required this.onTap,
    required this.p,
    required this.l10n,
  });
  final FoodEntry entry;

  /// Satır malzeme düzeltme sayfasını açar.
  final VoidCallback onTap;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: l10n.takipMealEditOpen(entry.yemekAdi),
      child: Pressable(onTap: onTap, child: _row()),
    );
  }

  Widget _row() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.yemekAdi,
                  style: AppTextStyles.heading(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.takipMacroSummary(
                    entry.protein,
                    entry.karbonhidrat,
                    entry.yag,
                  ),
                  style: AppTextStyles.body(fontSize: 11.5, color: p.textMuted),
                ),
                // Malzemeler kaydın parçası: "ne yedim" sorusuna makro
                // satırından daha iyi cevap veriyor. Eski kayıtlarda boş.
                if (entry.malzemeler.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.malzemeler.join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: p.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            l10n.takipKcal(entry.kalori),
            style: AppTextStyles.mono(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: p.textMuted,
            ),
          ),
          // Satırın açılabildiğini söyleyen tek işaret; ok olmadan düzeltme
          // kapısı görünmez kalıyordu.
          Icon(Icons.chevron_right_rounded, size: 16, color: p.border),
        ],
      ),
    );
  }
}

class _AddMealRow extends StatelessWidget {
  const _AddMealRow({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push(routeYemekEkle),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.takipAddMeal,
                style: AppTextStyles.display(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: p.textMuted,
                ),
              ),
            ),
            Icon(Icons.add_rounded, size: 18, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── SECTION 3: Activity (alışkanlık + su — ikisi de gerçek veri) ────────────

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterMl = ref.watch(selectedDayWaterProvider);
    final waterPct = (waterMl / _kSuHedef).clamp(0.0, 1.0);
    final range = ref.watch(trackingRangeProvider);
    final history = ref.watch(selectedDayWaterHistoryProvider);
    final waterAverage = history.isEmpty
        ? 0
        : (history.reduce((a, b) => a + b) / history.length).round();
    // Sahte "4.2k adım" yer tutucusu kaldırıldı — adım verisi ancak sensör
    // entegrasyonuyla gelir (post-MVP). Yerine elimizde GERÇEKTEN olan
    // metrik: seçili gündeki alışkanlık tamamlama sayısı.
    final habitCount = ref.watch(habitsProvider).valueOrNull?.length ?? 0;
    final doneCount = ref
        .watch(selectedDayCompletionsProvider)
        .valueOrNull
        ?.length
        .clamp(0, habitCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l10n.takipActivityLabel, color: p.textMuted),
        Row(
          children: [
            Expanded(
              child: _Card(
                p: p,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${doneCount ?? 0} / $habitCount',
                      style: AppTextStyles.mono(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.takipHabitsDoneLabel,
                      style: AppTextStyles.label(
                        fontSize: 11.5,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Water — real data from SharedPreferences
            Expanded(
              child: _Card(
                p: p,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${waterMl}ml',
                      style: AppTextStyles.mono(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: waterPct,
                        minHeight: 3,
                        backgroundColor: p.border,
                        color: p.water,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.takipWaterGoal(_kSuHedef),
                      style: AppTextStyles.label(
                        fontSize: 10,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Seçili pencerenin (hafta/ay) günlük ortalaması: tek
                    // günün iyi ya da kötü geçmesi alışkanlığı anlatmıyor.
                    // Pencere seçili günde biter, bugünde değil.
                    Text(
                      l10n.takipWaterAverage(
                        rangeLabel(range, l10n),
                        waterAverage,
                      ),
                      style: AppTextStyles.label(
                        fontSize: 10,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── SECTION 4: Habits — Firestore'den gerçek veri ─────────────────────

class _HabitsSection extends ConsumerWidget {
  const _HabitsSection({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(trackingRangeProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final completionsAsync = ref.watch(selectedDayRangeCompletionsProvider);
    final dayCompletions =
        ref.watch(selectedDayCompletionsProvider).valueOrNull ?? {};
    final isToday = ref.watch(isTodaySelectedProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final toggle = ref.read(toggleHabitCompletionProvider);

    final habits = habitsAsync.valueOrNull ?? [];
    final completions = completionsAsync.valueOrNull ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık satırı pencere seçimini taşır: ızgara ayrı bir ekrana gitmeden
        // yakınlaşıp uzaklaşır.
        Row(
          children: [
            Expanded(
              child: _SectionLabel(l10n.takipHabitsLabel, color: p.textMuted),
            ),
            _RangeToggle(p: p, l10n: l10n),
          ],
        ),
        if (habitsAsync.isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: p.accent,
                strokeWidth: 1.5,
              ),
            ),
          )
        else if (habits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              l10n.takipNoHabitsYet,
              style: AppTextStyles.body(
                fontSize: 13,
                color: p.textMuted,
                height: 1.5,
              ),
            ),
          )
        else
          Column(
            children: habits.asMap().entries.map((e) {
              final isLast = e.key == habits.length - 1;
              final habit = e.value;
              final isDone = dayCompletions.contains(habit.id);
              return Column(
                children: [
                  _HabitRow(
                    habitId: habit.id,
                    name: habit.name,
                    completions: completions,
                    range: range,
                    endDay: selectedDay,
                    isSelectedDayDone: isDone,
                    // Geçmiş gün işaretlenmez: dünü bugünmüş gibi
                    // işaretlemek streak'i ve kaydı bozar. Silme açık
                    // kalır, o güne değil alışkanlığın kendisine aittir.
                    onToggle: isToday ? () => toggle(habit.id) : null,
                    // Uzun basma silme kapısı. `deleteHabit` repository'de
                    // yazılıydı ve kural izin veriyordu ama hiçbir yerden
                    // çağrılmıyordu: kullanıcı eklediği alışkanlığı
                    // kaldıramıyordu.
                    onDelete: () => _confirmDeleteHabit(
                      context,
                      ref,
                      habitId: habit.id,
                      name: habit.name,
                    ),
                    p: p,
                  ),
                  if (!isLast) _Hairline(p: p),
                ],
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// Hafta / ay seçimi. İki değerlik bir seçim için açılır menü fazla: iki hap,
/// seçili olan dolu.
class _RangeToggle extends ConsumerWidget {
  const _RangeToggle({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(trackingRangeProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TrackingRange.values.map((range) {
          final isSelected = range == selected;
          final label = rangeLabel(range, l10n);
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: label,
              child: Pressable(
                onTap: () =>
                    ref.read(trackingRangeProvider.notifier).state = range,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? p.accent : p.surfaceStrong,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: AppTextStyles.label(
                      fontSize: 11,
                      color: isSelected ? p.onAccent : p.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Alışkanlığı onaylı olarak siler.
///
/// Onay şart: silme geri alınamıyor ve geçmiş işaretlemeler de listeden
/// kalkıyor.
Future<void> _confirmDeleteHabit(
  BuildContext context,
  WidgetRef ref, {
  required String habitId,
  required String name,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await confirmDelete(
    context,
    title: l10n.habitDeleteTitle,
    body: l10n.habitDeleteBody,
  );
  if (!ok || !context.mounted) return;

  try {
    await ref.read(deleteHabitProvider)(habitId);
    if (context.mounted) IlndToast.success(context, l10n.habitDeleted);
  } catch (_) {
    if (context.mounted) IlndToast.error(context, l10n.habitDeleteFailed);
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habitId,
    required this.name,
    required this.completions,
    required this.range,
    required this.endDay,
    required this.isSelectedDayDone,
    required this.onToggle,
    required this.onDelete,
    required this.p,
  });

  final String habitId;
  final String name;
  final Map<String, Set<String>> completions;
  final TrackingRange range;

  /// Izgaranın son hücresi. Bugün olmak zorunda değil: gezgin geriye
  /// gittiğinde pencere de onunla birlikte kayar.
  final DateTime endDay;

  final bool isSelectedDayDone;

  /// Geçmiş günde null: o gün işaretlenemez.
  final VoidCallback? onToggle;
  final VoidCallback onDelete;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    // Izgara eskiden yeniye kurulur; son hücre seçili gündür. Gün aritmetiği
    // takvimle yapılır — yaz saati geçişinde Duration ile çıkarma aynı güne
    // düşebiliyor.
    final dates = List.generate(
      range.days,
      (i) => _dayKey(
        DateTime(endDay.year, endDay.month, endDay.day - (range.days - 1 - i)),
      ),
    );
    bool doneOn(String date) => date == dates.last
        ? isSelectedDayDone
        : (completions[date]?.contains(habitId) ?? false);
    final doneCount = dates.where(doneOn).length;

    // Hafta yedi hücre: isimle aynı satıra sığar. Ay otuz hücre: ızgara alt
    // satıra geçer ve hücreler küçülür.
    final isWeek = range == TrackingRange.week;
    final cells = [
      for (final date in dates)
        _DayCell(
          done: doneOn(date),
          isSelectedDay: date == dates.last,
          size: isWeek ? 18 : 10,
          p: p,
        ),
    ];

    final title = Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: AppTextStyles.body(
              fontSize: 14,
              color: p.text,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$doneCount/${range.days}',
          style: AppTextStyles.mono(fontSize: 12.5, color: p.textMuted),
        ),
      ],
    );

    return Pressable(
      onTap: onToggle,
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: isWeek
            ? Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  Row(children: cells),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 10),
                  Wrap(spacing: 4, runSpacing: 4, children: cells),
                ],
              ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.done,
    required this.isSelectedDay,
    required this.size,
    required this.p,
  });

  final bool done;

  /// Çerçeveli hücre: ızgaranın hangi gününe bakıldığını söyler.
  final bool isSelectedDay;
  final double size;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final isLarge = size >= 18;
    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.only(left: isLarge ? 4 : 0),
      decoration: BoxDecoration(
        color: done ? p.accent : p.surfaceStrong,
        borderRadius: BorderRadius.circular(isLarge ? 4 : 2),
        border: isSelectedDay ? Border.all(color: p.accent, width: 1.5) : null,
      ),
      child: done && isLarge
          ? Icon(Icons.check_rounded, size: 11, color: p.onAccent)
          : null,
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────

String rangeLabel(TrackingRange range, AppLocalizations l10n) =>
    range == TrackingRange.week ? l10n.takipRangeWeek : l10n.takipRangeMonth;

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
