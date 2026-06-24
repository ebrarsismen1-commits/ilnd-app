import 'package:flutter/material.dart';

/// Tek bir titreşen iskelet kutu — renk tema'ya göre ayarlanır.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF20242B) : const Color(0xFFE8E6E1);
    final highlight = isDark ? const Color(0xFF2A3040) : const Color(0xFFF5F4F1);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context2, child2) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, highlight, _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Bir kart iskelet — isteğe bağlı satır sayısı ile.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.lines = 3,
    this.height,
    required this.p,
  });

  final int lines;
  final double? height;
  final dynamic p; // AppPalette

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SkeletonBox(width: 80, height: 10, radius: 4),
          const SizedBox(height: 12),
          for (int i = 0; i < lines; i++) ...[
            SkeletonBox(
              width: i == lines - 1 ? 140 : double.infinity,
              height: 12,
              radius: 4,
            ),
            if (i < lines - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
