import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';

/// Nefes alma animasyonu — dairesel pulse, "al / tut / ver" rehberi ile.
class BreathAnimation extends StatefulWidget {
  const BreathAnimation({super.key, required this.p});
  final AppPalette p;

  @override
  State<BreathAnimation> createState() => _BreathAnimationState();
}

class _BreathAnimationState extends State<BreathAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  // Nefes döngüsü: 4sn al, 4sn tut, 6sn ver = 14sn
  static const _inhale = 4.0;
  static const _hold = 4.0;
  static const _exhale = 6.0;
  static const _total = _inhale + _hold + _exhale;

  String _label = 'al';

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 14000), // _total * 1000
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) _ctrl.repeat();
        });

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.65,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: _inhale,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: _hold),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.65,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: _exhale,
      ),
    ]).animate(_ctrl);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: _inhale),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: _hold),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: _exhale),
    ]).animate(_ctrl);

    _ctrl.addListener(_updateLabel);
    _ctrl.forward();
  }

  void _updateLabel() {
    final t = _ctrl.value * _total;
    String next;
    if (t < _inhale) {
      next = 'al';
    } else if (t < _inhale + _hold) {
      next = 'tut';
    } else {
      next = 'ver';
    }
    if (next != _label) setState(() => _label = next);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_updateLabel);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Dış halka (daha yavaş, soluk)
            Transform.scale(
              scale: _scale.value * 1.3,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent.withValues(alpha: _opacity.value * 0.12),
                ),
              ),
            ),
            // Orta halka
            Transform.scale(
              scale: _scale.value * 1.1,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent.withValues(alpha: _opacity.value * 0.18),
                ),
              ),
            ),
            // Ana daire
            Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      p.accent.withValues(alpha: 0.85),
                      p.accent.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _label,
                        key: ValueKey(_label),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: p.onAccent,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tam ekran nefes egzersizi sayfası.
class BreathScreen extends StatelessWidget {
  const BreathScreen({super.key, required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: p.base,
      appBar: AppBar(
        backgroundColor: p.base,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: p.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'nefes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w300,
            color: p.text,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Spacer(),
          BreathAnimation(p: p),
          const SizedBox(height: 40),
          Text(
            '4 · 4 · 6',
            style: TextStyle(
              fontSize: 13,
              color: p.textMuted,
              letterSpacing: 3,
            ),
          ),
          Text(
            'al · tut · ver',
            style: TextStyle(
              fontSize: 12,
              color: p.textMuted.withValues(alpha: 0.6),
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
