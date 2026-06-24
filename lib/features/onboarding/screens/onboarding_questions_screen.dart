import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

class OnboardingQuestionsScreen extends ConsumerStatefulWidget {
  const OnboardingQuestionsScreen({super.key});

  @override
  ConsumerState<OnboardingQuestionsScreen> createState() =>
      _OnboardingQuestionsScreenState();
}

class _OnboardingQuestionsScreenState
    extends ConsumerState<OnboardingQuestionsScreen> {
  int _step = 0;

  // Hedef kalori & besin takibi, aktivite, alışkanlık, ruh hali
  static const _goals = [
    ('Kalori & besin takibi', '🍽️'),
    ('Kilo vermek / almak', '⚖️'),
    ('Daha fazla hareket etmek', '🏃'),
    ('Su & uyku takibi', '💧'),
    ('Alışkanlık oluşturmak', '🔄'),
    ('Ruh halini takip etmek', '💙'),
  ];

  static const _activityLevels = [
    ('Çok az', 'Masabaşı iş, egzersiz yok'),
    ('Az aktif', 'Haftada 1–2 gün hafif egzersiz'),
    ('Orta aktif', 'Haftada 3–4 gün antrenman'),
    ('Çok aktif', 'Her gün yoğun egzersiz'),
  ];

  void _next() {
    if (_step < 1) {
      setState(() => _step++);
    } else {
      context.go(routeNameInput);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(onboardingGoalsProvider);
    final frequency = ref.watch(onboardingFrequencyProvider);

    final canProceed = _step == 0 ? goals.isNotEmpty : frequency != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
              child: Row(
                children: [
                  _Dot(active: true),
                  const SizedBox(width: 6),
                  _Dot(active: _step >= 1),
                ],
              ),
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
                child: _step == 0
                    ? _GoalsStep(key: const ValueKey(0), selected: goals)
                    : _ActivityStep(key: const ValueKey(1), selected: frequency),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Pressable(
                onTap: canProceed ? _next : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: canProceed
                        ? AppColors.sage
                        : AppColors.sage.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _step == 0 ? 'Devam' : 'Hadi başlayalım',
                    style: AppTextStyles.body(fontSize: 15, color: AppColors.white)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 1: Hedefler ─────────────────────────────────────────────────────────

class _GoalsStep extends ConsumerWidget {
  const _GoalsStep({super.key, required this.selected});
  final List<String> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = _OnboardingQuestionsScreenState._goals;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Neyi takip etmek\nistiyorsun?',
              style: AppTextStyles.display(fontSize: 26)),
          const SizedBox(height: 6),
          Text('Birden fazla seçebilirsin.',
              style: AppTextStyles.body(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 28),
          ...items.map((item) {
            final on = selected.contains(item.$1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () =>
                    ref.read(onboardingGoalsProvider.notifier).toggle(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: on
                        ? AppColors.sage.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: on
                          ? AppColors.sage
                          : AppColors.muted.withValues(alpha: 0.2),
                      width: on ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(item.$2,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(item.$1,
                            style: AppTextStyles.body(
                              fontSize: 15,
                              color: on ? AppColors.sage : AppColors.charcoal,
                            ).copyWith(
                                fontWeight: on
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ),
                      if (on)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.sage, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Step 2: Aktivite seviyesi ─────────────────────────────────────────────────

class _ActivityStep extends ConsumerWidget {
  const _ActivityStep({super.key, required this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = _OnboardingQuestionsScreenState._activityLevels;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aktivite\nseviyeni seç.',
              style: AppTextStyles.display(fontSize: 26)),
          const SizedBox(height: 6),
          Text('Kalori hedefini buna göre ayarlayacağız.',
              style: AppTextStyles.body(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 28),
          ...items.map((item) {
            final on = selected == item.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () => ref
                    .read(onboardingFrequencyProvider.notifier)
                    .select(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: on
                        ? AppColors.sage.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: on
                          ? AppColors.sage
                          : AppColors.muted.withValues(alpha: 0.2),
                      width: on ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$1,
                                style: AppTextStyles.body(
                                  fontSize: 15,
                                  color: on
                                      ? AppColors.sage
                                      : AppColors.charcoal,
                                ).copyWith(
                                    fontWeight: on
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                            const SizedBox(height: 2),
                            Text(item.$2,
                                style: AppTextStyles.body(
                                    fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      if (on)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.sage, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Progress dot ──────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? AppColors.sage
            : AppColors.muted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
