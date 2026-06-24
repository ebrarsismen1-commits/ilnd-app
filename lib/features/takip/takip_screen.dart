import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';

// ─── Hardcoded data models ────────────────────────────────────────────────────

class _Macro {
  const _Macro(this.label, this.current, this.goal, this.unit, this.color);
  final String label;
  final double current;
  final double goal;
  final String unit;
  final Color color;
}

class _Meal {
  const _Meal(this.name, this.description, this.kcal);
  final String name;
  final String description;
  final int kcal;
}

class _Habit {
  const _Habit(this.name, this.checkedDays);
  final String name;
  final int checkedDays;
}

const _macros = [
  _Macro('Kalori', 1840, 2000, 'kcal', AppColors.amber),
  _Macro('Protein', 94, 130, 'g', AppColors.sage),
  _Macro('Karb', 210, 250, 'g', AppColors.sageLight),
  _Macro('Yağ', 58, 70, 'g', AppColors.amberLight),
];

const _meals = [
  _Meal('Kahvaltı', 'Yulaf + muz + badem sütü', 420),
  _Meal('Öğle', 'Tavuklu salata + bulgur', 650),
];

const _habits = [
  _Habit('Meditasyon', 3),
  _Habit('Okuma', 2),
  _Habit('Su içme', 5),
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

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return _Card(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('BUGÜNÜN MAKROLARI', color: p.accent),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DonutChart(p: p),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _macros.map((m) => _MacroRow(macro: m, p: p)).toList(),
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
  const _DonutChart({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final protein = _macros[1];
    final karb = _macros[2];
    final fat = _macros[3];
    final total = protein.current + karb.current + fat.current;

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
              sections: [
                PieChartSectionData(value: protein.current / total * 100, color: protein.color, radius: 17, showTitle: false),
                PieChartSectionData(value: karb.current / total * 100, color: karb.color, radius: 17, showTitle: false),
                PieChartSectionData(value: fat.current / total * 100, color: fat.color, radius: 17, showTitle: false),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1840',
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
  const _MacroRow({required this.macro, required this.p});
  final _Macro macro;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final label = macro.unit == 'kcal'
        ? '${macro.current.toInt()} / ${macro.goal.toInt()}'
        : '${macro.current.toInt()}${macro.unit} / ${macro.goal.toInt()}${macro.unit}';

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
                  color: macro.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(macro.label, style: AppTextStyles.body(fontSize: 12, color: p.textMuted)),
            ],
          ),
          Text(label,
              style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w500, color: macro.color)),
        ],
      ),
    );
  }
}

// ─── SECTION 2: Meals ─────────────────────────────────────────────────────────

class _MealsSection extends StatelessWidget {
  const _MealsSection({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('ÖĞÜNLER', color: p.textMuted),
        _Card(
          p: p,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ..._meals.asMap().entries.map((e) {
                final isLast = e.key == _meals.length - 1;
                return Column(
                  children: [
                    _MealRow(meal: e.value, p: p),
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

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.p});
  final _Meal meal;
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
                Text(meal.name,
                    style: AppTextStyles.heading(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 2),
                Text(meal.description, style: AppTextStyles.body(fontSize: 12, color: p.textMuted)),
              ],
            ),
          ),
          Text('${meal.kcal} kcal',
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
      onTap: () {},
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
