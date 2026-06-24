import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 3),
              Text('ilnd.', style: AppTextStyles.displayHero()),
              const SizedBox(height: 20),
              Text(
                'kendi içine dön.',
                style: AppTextStyles.body(
                  fontSize: 18,
                  color: AppColors.muted,
                ).copyWith(letterSpacing: 0.2),
              ),
              Text(
                'come back to yourself.',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.muted.withValues(alpha: 0.7),
                ).copyWith(letterSpacing: 0.2),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.push(routeValueProps),
                  child: const Text('Başla'),
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
