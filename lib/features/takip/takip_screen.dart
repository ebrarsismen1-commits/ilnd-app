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

// ─── Statik hedefler (ileride kullanıcıya göre hesaplanacak) ─────────────────

const _kKaloriHedef = 2000;
const _kProteinHedef = 130;
const _kKarbHedef = 250;
const _kYagHedef = 70;

// ─── Alışkanlıklar (şimdilik sabit, Phase 2C'de dinamik olacak) ──────────────

class _Habit {
  const _Habit(this.name, this.checkedDays);
  final String name;
  final int checkedDays;
}

const _habits = [
  _Habit('Su içme', 5),
  _Habit('Hareket', 3),
  _Habit('Uyku', 4),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class TakipScreen extends ConsumerWidget {
  const TakipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding, 28, AppSpacing.screenPadding, 0),
                  child: Text('takip.',
                      style: AppTextStyles.display(fontSize: 32, color: p.text)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding, 20, AppSpacing.screenPadding, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    Entrance(index: 0, child: _MacroCard(p: p)),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(index: 1, child: _MealsSection(p: p)),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(index: 2, child: _ActivitySection(p: p)),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Entrance(index: 3, child: _HabitsSection(p: p)),
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
  const _MacroCard({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = ref.watch(dailyMacrosProvider);
    return _Card(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('BUGÜNÜN MAKROLARI', color: p.accent),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DonutChart(p: p, macros: macros),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MacroRow(label: 'Kalori', current: macros.kalori, goal: _kKaloriHedef, unit: 'kcal', color: AppColors.amber, p: p),
                    _MacroRow(label: 'Protein', current: macros.protein, goal: _kProteinHedef, unit: 'g', color: AppColors.sage, p: p),
                    _MacroRow(label: 'Karb', current: macros.karbonhidrat, goal: _kKarbHedef, unit: 'g', color: AppColors.sageLight, p: p),
                    _MacroRow(label: 'Yağ', current: macros.yag, goal: _kYagHedef, unit: 'g', color: AppColors.amberLight, p: p),
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
    final total = (macros.protein + macros.karbonhidrat + macros.yag).toDouble();
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
                      PieChartSectionData(value: macros.protein / total * 100, color: AppColors.sage, radius: 17, showTitle: false),
                      PieChartSectionData(value: macros.karbonhidrat / total * 100, color: AppColors.sageLight, radius: 17, showTitle: false),
                      PieChartSectionData(value: macros.yag / total * 100, color: AppColors.amberLight, radius: 17, showTitle: false),
                    ]
                  : [PieChartSectionData(value: 100, color: p.border, radius: 17, showTitle: false)],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${macros.kalori}',
                  style: AppTextStyles.mono(fontSize: 18, fontWeight: FontWeight.w600, color: p.text)),
              Text('kcal',
                  style: AppTextStyles.label(fontSize: 10, color: p.textMuted)
                      .copyWith(letterSpacing: 0)),
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
              Text(label, style: AppTextStyles.body(fontSize: 12, color: p.textMuted)),
            ],
          ),
          Text(text,
              style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}

// ─── SECTION 2: Meals ─────────────────────────────────────────────────────────

class _MealsSection extends ConsumerWidget {
  const _MealsSection({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(todayFoodEntriesProvider);
    final entries = entriesAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('ÖĞÜNLER', color: p.textMuted),
        _Card(
          p: p,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Text('Henüz yemek eklenmedi.',
                      style: AppTextStyles.body(fontSize: 13, color: p.textMuted)),
                )
              else
                ...entries.asMap().entries.map((e) {
                final isLast = e.key == entries.length - 1;
                return Column(
                  children: [
                    _FoodEntryRow(entry: e.value, p: p),
                    if (!isLast) Divider(height: 1, indent: 16, endIndent: 16, color: p.border),
                  ],
                );
              }),
              Divider(height: 1, indent: 16, endIndent: 16, color: p.border),
              _AddMealRow(p: p),
            ],
          ),
        ),
      ],
    );
  }
}

class _FoodEntryRow extends StatelessWidget {
  const _FoodEntryRow({required this.entry, required this.p});
  final FoodEntry entry;
  final AppPalette p;

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
                Text(entry.yemekAdi,
                    style: AppTextStyles.heading(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 2),
                Text('P: ${entry.protein}g  K: ${entry.karbonhidrat}g  Y: ${entry.yag}g',
                    style: AppTextStyles.body(fontSize: 12, color: p.textMuted)),
              ],
            ),
          ),
          Text('${entry.kalori} kcal',
              style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w500, color: p.textMuted)),
        ],
      ),
    );
  }
}

class _AddMealRow extends StatelessWidget {
  const _AddMealRow({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push(routeYemekEkle),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text('Akşam ekle…',
                  style: AppTextStyles.display(fontSize: 14, fontWeight: FontWeight.w400, color: p.textMuted)),
            ),
            Icon(Icons.add_rounded, size: 18, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── SECTION 3: Activity ──────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('AKTİVİTE', color: p.textMuted),
        Row(
          children: [
            Expanded(
              child: _Card(
                p: p,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('4.2k', style: AppTextStyles.mono(fontSize: 24, fontWeight: FontWeight.w600, color: p.text)),
                    const SizedBox(height: 4),
                    Text('adım', style: AppTextStyles.label(fontSize: 11, color: p.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Card(
                p: p,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('34', style: AppTextStyles.mono(fontSize: 24, fontWeight: FontWeight.w600, color: p.text)),
                    const SizedBox(height: 4),
                    Text('aktif dk', style: AppTextStyles.label(fontSize: 11, color: p.textMuted)),
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

// ─── SECTION 4: Habits ───────────────────────────────────────────────────────

class _HabitsSection extends StatelessWidget {
  const _HabitsSection({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('GÜNLÜK ALIŞKANLIKLAR', color: p.textMuted),
        _Card(
          p: p,
          padding: EdgeInsets.zero,
          child: Column(
            children: _habits.asMap().entries.map((e) {
              final isLast = e.key == _habits.length - 1;
              return Column(
                children: [
                  _HabitRow(habit: e.value, p: p),
                  if (!isLast) Divider(height: 1, indent: 16, endIndent: 16, color: p.border),
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
  const _HabitRow({required this.habit, required this.p});
  final _Habit habit;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(habit.name,
                style: AppTextStyles.body(fontSize: 14, color: p.text)
                    .copyWith(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Row(
            children: List.generate(7, (i) {
              final checked = i < habit.checkedDays;
              return Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: checked ? p.accent : p.surfaceStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: checked ? Icon(Icons.check_rounded, size: 11, color: p.onAccent) : null,
              );
            }),
          ),
        ],
      ),
    );
  }
}
