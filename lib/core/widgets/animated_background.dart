import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ilnd_app/core/widgets/motion.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';

/// Yavaşça akan, nefes alan arka plan.
///
/// Gündüz: pastel aura degradesi yumuşakça döner. Gece: mürekkep zeminde
/// sage ışıltısı dolaşır. Görsel asset olmadan ekrana hayat katar.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({
    super.key,
    required this.palette,
    this.child,
    this.lowPower,
  });

  final AppPalette palette;
  final Widget? child;

  /// Web'de her karede 3 tam ekran gradyan boyamak (60fps) yazılım-render'lı
  /// tarayıcılarda ekranı donduruyordu — lowPower animasyonu ~12fps'e
  /// kuantalar; 18 sn'lik süzülme bu hızda da akıcı görünür.
  /// null = platforma göre otomatik (web'de açık).
  final bool? lowPower;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(seconds: 18);
  static const _lowPowerFps = 12;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();

  /// lowPower modunda boyamayı tetikleyen kuantalanmış değer — yalnız
  /// 1/12 sn'lik adım değişince güncellenir, aradaki tick'ler boyama üretmez.
  late final ValueNotifier<double> _quantized = ValueNotifier(_c.value);

  bool get _lowPower => widget.lowPower ?? kIsWeb;

  @override
  void initState() {
    super.initState();
    if (_lowPower) _c.addListener(_onTick);
  }

  void _onTick() {
    final steps = _cycle.inSeconds * _lowPowerFps;
    final q = (_c.value * steps).floorToDouble() / steps;
    if (q != _quantized.value) _quantized.value = q;
  }

  @override
  void dispose() {
    _quantized.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    // Hareket azaltılmışsa zemin DONDURULUR: aynı gradyan çizilir ama
    // süzülmez. Sürekli tam ekran hareket, vestibüler rahatsızlığı olan
    // kullanıcıda baş dönmesi yapan tam olarak bu tür harekettir — ve
    // dekoratif olduğu için durması hiçbir bilgi kaybettirmez.
    final frozen = prefersReducedMotion(context);
    return AnimatedBuilder(
      animation: _lowPower ? _quantized : _c,
      builder: (context, child) {
        final value = frozen ? 0.0 : (_lowPower ? _quantized.value : _c.value);
        final t = value * 2 * math.pi;
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
