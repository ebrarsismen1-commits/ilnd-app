import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';

/// ilnd'nin marka jesti: nefes alan halka.
///
/// Tasarım dili "nefes"tir (docs/DESIGN_SYSTEM.md §4): 4 sn genişle /
/// 6 sn daral. Navigasyon merkezi, sohbet başlığı ve yükleme durumları
/// aynı ritmi paylaşır — jest her yerde tek.
class BreathRing extends ConsumerStatefulWidget {
  const BreathRing({super.key, this.size = 56, this.onTap, this.semanticLabel});

  /// Dış (yumuşak) dairenin çapı; iç halka orana göre ölçeklenir.
  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  ConsumerState<BreathRing> createState() => _BreathRingState();
}

class _BreathRingState extends ConsumerState<BreathRing>
    with SingleTickerProviderStateMixin {
  // 4 sn al + 6 sn ver = 10 sn'lik tek döngü.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.14,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 40, // nefes al — 4 sn
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.14,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 60, // nefes ver — 6 sn
    ),
  ]).animate(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final inner = widget.size * 0.68;

    final ring = ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Container(
          width: inner,
          height: inner,
          decoration: BoxDecoration(
            color: p.base,
            shape: BoxShape.circle,
            border: Border.all(color: p.accent, width: 2.5),
          ),
        ),
      ),
    );

    if (widget.onTap == null) return ring;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ring,
      ),
    );
  }
}
