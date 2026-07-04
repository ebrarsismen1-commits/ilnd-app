import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';

/// Yavaşça akan, nefes alan arka plan.
///
/// Gündüz: pastel aura degradesi yumuşakça döner. Gece: mürekkep zeminde
/// sage ışıltısı dolaşır. Görsel asset olmadan ekrana hayat katar.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, required this.palette, this.child});

  final AppPalette palette;
  final Widget? child;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value * 2 * math.pi;
        // Degradenin yönü yavaşça döner.
        final begin = Alignment(math.cos(t) * 0.8, math.sin(t) * 0.8);
        final end = Alignment(-math.cos(t) * 0.8, -math.sin(t) * 0.8);

        // İki ışık lekesi farklı hızlarda süzülür.
        final g1 = Alignment(math.sin(t * 0.7) * 0.7, math.cos(t * 0.9) * 0.7);
        final g2 = Alignment(math.cos(t * 1.1) * 0.8, math.sin(t * 0.6) * 0.8);

        final glow = p.isDark
            ? p.accent.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.35);
        final glow2 = p.isDark
            ? p.amber.withValues(alpha: 0.12)
            : p.aura.last.withValues(alpha: 0.5);

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: begin,
                  end: end,
                  colors: p.aura,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: g1,
                  radius: 0.9,
                  colors: [glow, glow.withValues(alpha: 0.0)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: g2,
                  radius: 1.0,
                  colors: [glow2, glow2.withValues(alpha: 0.0)],
                ),
              ),
            ),
            ?child,
          ],
        );
      },
      // İçerik ayrı raster katmanında: gradyanlar her karede boyanırken
      // (tasarım gereği "nefes") ekran içeriği yeniden rasterize edilmez.
      child: widget.child == null ? null : RepaintBoundary(child: widget.child),
    );
  }
}
