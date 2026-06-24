import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_text_styles.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween(begin: 0.88, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo: "ilnd." büyük harf
              Text(
                'ilnd.',
                style: AppTextStyles.display(
                  fontSize: 56,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'iyi hisset, iyi yaşa.',
                style: TextStyle(
                  fontSize: 13,
                  color: p.textMuted,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: p.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
