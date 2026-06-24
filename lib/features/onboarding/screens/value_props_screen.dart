import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';

class ValuePropsScreen extends StatelessWidget {
  const ValuePropsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              Text('ilnd nedir?', style: AppTextStyles.display(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                'what is ilnd?',
                style: AppTextStyles.body(fontSize: 14, color: AppColors.muted),
              ),
              const Spacer(flex: 1),
              const _ValuePropTile(
                icon: Icons.favorite_border_rounded,
                titleTr: 'Ruh hali takibi',
                titleEn: 'Mood tracking',
                descTr: 'Her gün kendine sor, nasıl hissediyorsun?',
                descEn: 'Ask yourself daily — how are you feeling?',
              ),
              const SizedBox(height: 28),
              const _ValuePropTile(
                icon: Icons.edit_outlined,
                titleTr: 'Günlük',
                titleEn: 'Journaling',
                descTr: 'Düşüncelerini yaz, içini boşalt.',
                descEn: 'Write your thoughts, clear your mind.',
              ),
              const SizedBox(height: 28),
              const _ValuePropTile(
                icon: Icons.spa_outlined,
                titleTr: 'Kişisel büyüme',
                titleEn: 'Personal growth',
                descTr: 'Alışkanlıklarını izle, kendinle büyü.',
                descEn: 'Track habits, grow with yourself.',
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.push(routeOnboardingQuestions),
                  child: const Text('Devam'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValuePropTile extends StatelessWidget {
  const _ValuePropTile({
    required this.icon,
    required this.titleTr,
    required this.titleEn,
    required this.descTr,
    required this.descEn,
  });

  final IconData icon;
  final String titleTr;
  final String titleEn;
  final String descTr;
  final String descEn;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.sageLight.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall + 4),
          ),
          child: Icon(icon, color: AppColors.sage, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleTr,
                style: AppTextStyles.heading(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                titleEn,
                style: AppTextStyles.body(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                descTr,
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.charcoal.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
