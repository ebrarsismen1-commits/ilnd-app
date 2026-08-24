import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/widgets/motion.dart';

/// Gradient shimmer efekti — yükleme sırasında placeholder olarak kullan.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Döngü burada başlar, initState'te değil: "hareketi azalt" ayarı
  /// MediaQuery'den okunur ve initState'te henüz güvenilir değildir.
  /// Azaltılmış modda hiç başlamaz — sonsuz tekrar eden bir denetleyici
  /// testte sahnenin hiç durulmamasına da yol açar.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (prefersReducedMotion(context)) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = isDark ? AppPalette.dark : AppPalette.light;
    final base = p.surfaceStrong;
    final highlight = isDark
        ? const Color(0xFF262C24) // surfaceStrong'un bir tık üstü, palette yok
        : p.surface;

    // Sürekli parıltı dekoratiftir: "hareketi azalt" açıkken düz bir zemin
    // kalır, yükleme yine anlaşılır (kural: erişilebilirlik > cila).
    if (prefersReducedMotion(context)) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: base,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value.clamp(0.0, 1.0),
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Kart şeklinde shimmer (feed list için).
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Eski lavanta paletinden kalan mor (#1A1528) buradaydı — palete alındı.
    final surface = isDark
        ? AppPalette.dark.surfaceStrong
        : AppPalette.light.surface;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ShimmerBox(width: 72, height: 72, borderRadius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(height: 12, width: 60, borderRadius: 6),
                SizedBox(height: 8),
                ShimmerBox(height: 16),
                SizedBox(height: 6),
                ShimmerBox(height: 12),
                SizedBox(height: 6),
                ShimmerBox(height: 12, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
