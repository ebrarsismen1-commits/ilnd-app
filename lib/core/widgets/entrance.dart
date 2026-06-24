import 'package:flutter/material.dart';

/// Bir öğeyi yukarıdan kayarak + solarak + scale ile sahneye sokar.
/// [index] ile gecikme kademelenir (stagger efekti).
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.delayStep = const Duration(milliseconds: 80),
    this.duration = const Duration(milliseconds: 550),
    this.offset = 24,
  });

  final Widget child;
  final int index;
  final Duration delayStep;
  final Duration duration;
  final double offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutQuart);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delayStep * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offset),
          child: Transform.scale(
            scale: 0.96 + _curve.value * 0.04,
            child: child,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}
