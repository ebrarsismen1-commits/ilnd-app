import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

class NameInputScreen extends ConsumerStatefulWidget {
  const NameInputScreen({super.key});

  @override
  ConsumerState<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends ConsumerState<NameInputScreen> {
  final _controller = TextEditingController();
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final trimmed = _controller.text.trim();
      if ((trimmed.isNotEmpty) != _canProceed) {
        setState(() => _canProceed = trimmed.isNotEmpty);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await ref.read(userNameProvider.notifier).save(name);
    await ref.read(onboardingDoneProvider.notifier).setDone();
    if (mounted) context.go(routeRegister); // onboarding bitti → hesap oluştur
  }

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
              Text(
                'Seni nasıl\nçağıralım?',
                style: AppTextStyles.display(fontSize: 28),
              ),
              const SizedBox(height: 6),
              Text(
                'What should we call you?',
                style: AppTextStyles.body(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 52,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: AppTextStyles.body(
                    fontSize: 16,
                    color: AppColors.charcoal,
                  ).copyWith(fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'ismin…',
                  ),
                  onSubmitted: (_) => _proceed(),
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canProceed ? _proceed : null,
                  child: const Text('Hazırım'),
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
