import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
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
        Entrance(
          index: startIndex,
          child: _MacroCard(p: p, l10n: l10n),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Entrance(
          index: startIndex + 1,
          child: _MealsSection(p: p, l10n: l10n),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Entrance(
          index: startIndex + 2,
          child: _ActivitySection(p: p, l10n: l10n),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Entrance(
          index: startIndex + 3,
          child: _HabitsSection(p: p, l10n: l10n),
        ),
      ],
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
/// Ekranın kahramanı artık tek bir sayı — bugünkü kalori.
class _MacroCard extends ConsumerWidget {
  const _MacroCard({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = ref.watch(dailyMacrosProvider);
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
            Text(
              '/ $_kKaloriHedef kcal',
              style: AppTextStyles.mono(fontSize: 13, color: p.textMuted),
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
    final entriesAsync = ref.watch(todayFoodEntriesProvider);
    final entries = entriesAsync.valueOrNull ?? [];

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
                  l10n.takipNoMealsYet,
                  style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
                ),
              )
            else
              ...entries.map(
                (entry) => Column(
                  children: [
                    _FoodEntryRow(entry: entry, p: p, l10n: l10n),
                    _Hairline(p: p),
                  ],
                ),
              ),
            if (entries.isEmpty) _Hairline(p: p),
            _AddMealRow(p: p, l10n: l10n),
          ],
        ),
      ],
    );
  }
}

class _FoodEntryRow extends StatelessWidget {
  const _FoodEntryRow({
    required this.entry,
    required this.p,
    required this.l10n,
  });
  final FoodEntry entry;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
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
    final waterMl = ref.watch(waterTodayProvider);
    final waterPct = (waterMl / _kSuHedef).clamp(0.0, 1.0);
    // Sahte "4.2k adım" yer tutucusu kaldırıldı — adım verisi ancak sensör
    // entegrasyonuyla gelir (post-MVP). Yerine elimizde GERÇEKTEN olan
    // metrik: bugünkü alışkanlık tamamlama sayısı.
    final habitCount = ref.watch(habitsProvider).valueOrNull?.length ?? 0;
    final doneCount = ref
        .watch(todayCompletionsProvider)
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
                        color: const Color(0xFF93D5FF),
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

// ─── SECTION 4: Habits — Firestore'dan gerçek veri ───────────────────────────

class _HabitsSection extends ConsumerWidget {
  const _HabitsSection({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final completionsAsync = ref.watch(last7DaysCompletionsProvider);
    final todayCompletions =
        ref.watch(todayCompletionsProvider).valueOrNull ?? {};
    final toggle = ref.read(toggleHabitCompletionProvider);

    final habits = habitsAsync.valueOrNull ?? [];
    final last7 = completionsAsync.valueOrNull ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l10n.takipHabitsLabel, color: p.textMuted),
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
              final isToday = todayCompletions.contains(habit.id);
              return Column(
                children: [
                  _HabitRow(
                    habitId: habit.id,
                    name: habit.name,
                    last7: last7,
                    isTodayDone: isToday,
                    onToggle: () => toggle(habit.id),
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

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habitId,
    required this.name,
    required this.last7,
    required this.isTodayDone,
    required this.onToggle,
    required this.p,
  });

  final String habitId;
  final String name;
  final Map<String, Set<String>> last7;
  final bool isTodayDone;
  final VoidCallback onToggle;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    // Build 7-day grid: oldest → newest (today is last)
    final now = DateTime.now();
    final dates = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });

    return Pressable(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
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
            Row(
              children: dates.map((date) {
                final isToday = date == dates.last;
                final done = isToday
                    ? isTodayDone
                    : (last7[date]?.contains(habitId) ?? false);
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: done ? p.accent : p.surfaceStrong,
                    borderRadius: BorderRadius.circular(4),
                    border: isToday
                        ? Border.all(color: p.accent, width: 1.5)
                        : null,
                  ),
                  child: done
                      ? Icon(Icons.check_rounded, size: 11, color: p.onAccent)
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
