import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
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

class TakipScreen extends ConsumerWidget {
  const TakipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                  child: Row(
                    children: [
                      // Bu ekran nav v2'de sekmeden çıkıp Sen'den push edilen
                      // bir rotaya döndü (bkz. app_shell.dart) — geri butonu
                      // olmadan iOS'ta çıkış yolu yoktu. Gerçek bug, düzeltildi.
                      Pressable(
                        onTap: () => Navigator.of(context).maybePop(),
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
                      Text(
                        l10n.takipTitle,
                        style: AppTextStyles.display(
                          fontSize: 28,
                          color: p.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  20,
                  AppSpacing.screenPadding,
                  32,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    Entrance(
                      index: 0,
                      child: _MacroCard(p: p, l10n: l10n),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(
                      index: 1,
                      child: _MealsSection(p: p, l10n: l10n),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(
                      index: 2,
                      child: _ActivitySection(p: p, l10n: l10n),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(
                      index: 3,
                      child: _HabitsSection(p: p, l10n: l10n),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared card wrapper ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    required this.p,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
  });
  final Widget child;
  final AppPalette p;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: child,
    );
  }
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

// ─── SECTION 1: Macro card with donut chart ───────────────────────────────────

class _MacroCard extends ConsumerWidget {
  const _MacroCard({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = ref.watch(dailyMacrosProvider);
    return _Card(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(l10n.takipMacrosLabel, color: p.accent),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DonutChart(p: p, macros: macros),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MacroRow(
                      label: l10n.takipCalories,
                      current: macros.kalori,
                      goal: _kKaloriHedef,
                      unit: 'kcal',
                      color: p.amber,
                      p: p,
                    ),
                    _MacroRow(
                      label: l10n.takipProtein,
                      current: macros.protein,
                      goal: _kProteinHedef,
                      unit: 'g',
                      color: p.accent,
                      p: p,
                    ),
                    _MacroRow(
                      label: l10n.takipCarbs,
                      current: macros.karbonhidrat,
                      goal: _kKarbHedef,
                      unit: 'g',
                      color: p.accentSoft,
                      p: p,
                    ),
                    _MacroRow(
                      label: l10n.takipFat,
                      current: macros.yag,
                      goal: _kYagHedef,
                      unit: 'g',
                      color: p.amber.withValues(alpha: 0.6),
                      p: p,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.p, required this.macros});
  final AppPalette p;
  final DailyMacros macros;

  @override
  Widget build(BuildContext context) {
    final total = (macros.protein + macros.karbonhidrat + macros.yag)
        .toDouble();
    final hasData = total > 0;

    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: hasData
                  ? [
                      PieChartSectionData(
                        value: macros.protein / total * 100,
                        color: p.accent,
                        radius: 17,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: macros.karbonhidrat / total * 100,
                        color: p.accentSoft,
                        radius: 17,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: macros.yag / total * 100,
                        color: p.amber.withValues(alpha: 0.6),
                        radius: 17,
                        showTitle: false,
                      ),
                    ]
                  : [
                      PieChartSectionData(
                        value: 100,
                        color: p.border,
                        radius: 17,
                        showTitle: false,
                      ),
                    ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${macros.kalori}',
                style: AppTextStyles.mono(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
              Text(
                'kcal',
                style: AppTextStyles.label(
                  fontSize: 10,
                  color: p.textMuted,
                ).copyWith(letterSpacing: 0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.unit,
    required this.color,
    required this.p,
  });
  final String label;
  final int current;
  final int goal;
  final String unit;
  final Color color;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final text = unit == 'kcal'
        ? '$current / $goal'
        : '$current$unit / $goal$unit';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                label,
                style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
              ),
            ],
          ),
          Text(
            text,
            style: AppTextStyles.mono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
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
        _Card(
          p: p,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Text(
                    l10n.takipNoMealsYet,
                    style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
                  ),
                )
              else
                ...entries.asMap().entries.map((e) {
                  final isLast = e.key == entries.length - 1;
                  return Column(
                    children: [
                      _FoodEntryRow(entry: e.value, p: p, l10n: l10n),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: p.border,
                        ),
                    ],
                  );
                }),
              Divider(height: 1, indent: 16, endIndent: 16, color: p.border),
              _AddMealRow(p: p, l10n: l10n),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    fontSize: 15,
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
                  style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.takipAddMeal,
                style: AppTextStyles.display(
                  fontSize: 14,
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

// ─── SECTION 3: Activity (steps hardcoded, water real) ───────────────────────

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterMl = ref.watch(waterTodayProvider);
    final waterPct = (waterMl / _kSuHedef).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l10n.takipActivityLabel, color: p.textMuted),
        Row(
          children: [
            // Steps (placeholder — sensor entegrasyonu post-MVP)
            Expanded(
              child: _Card(
                p: p,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '4.2k',
                      style: AppTextStyles.mono(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.takipSteps,
                      style: AppTextStyles.label(
                        fontSize: 11,
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
                        fontSize: 22,
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
          _Card(
            p: p,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: p.accent,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          )
        else if (habits.isEmpty)
          _Card(
            p: p,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
              child: Text(
                l10n.takipNoHabitsYet,
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: p.textMuted,
                  height: 1.5,
                ),
              ),
            ),
          )
        else
          _Card(
            p: p,
            padding: EdgeInsets.zero,
            child: Column(
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
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: p.border,
                      ),
                  ],
                );
              }).toList(),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
