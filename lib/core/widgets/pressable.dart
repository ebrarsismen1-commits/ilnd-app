import 'package:flutter/material.dart';

/// Wraps [child] with a satisfying press animation:
/// scale 0.95 + slight brightness dim on tap down, spring back on release.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
    this.scaleDown = 0.94,
  });

  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;
  final double scaleDown;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: widget.scaleDown,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDown(TapDownDetails _) => _ctrl.forward();
  void _onUp(TapUpDetails _) => _ctrl.reverse();
  void _onCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: disabled ? null : _onDown,
      onTapUp: disabled ? null : _onUp,
      onTapCancel: disabled ? null : _onCancel,
      child: AnimatedOpacity(
        // onTap null'a düşünce kullanıcı "buton tıklanamaz" diye görsel
        // geri bildirim alır — önceden hiçbir dimming yoktu, dokunup hiçbir
        // şey olmadığını fark etmek zorunda kalıyordu.
        duration: const Duration(milliseconds: 150),
        opacity: disabled ? 0.45 : 1.0,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}
