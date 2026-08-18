import 'package:flutter/material.dart';
import 'package:ilnd_app/core/widgets/motion.dart';

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

  /// Gecikmenin durduğu adım — 6 * 80ms = 480ms tavan.
  static const int maxStaggerSteps = 6;

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
  // `late final` DEĞİL, initState'te kurulur: azaltılmış modda build erken
  // döndüğü için denetleyiciye hiç dokunulmuyordu, sonra dispose() onu
  // ATILMA ANINDA kuruyordu — Ticker o sırada inherited widget araması yapıp
  // "deactivated widget's ancestor" hatası veriyordu.
  late final AnimationController _c;
  late final Animation<double> _curve;

  bool _started = false;

  /// Kademelenme [maxStaggerSteps]'te durur. Sınırsızken ekranın altındaki
  /// öğeler saniyeye yaklaşan bir gecikmeyle giriyordu (Bugün'de 12. öğe =
  /// 960ms) — o noktada etki "kademeli giriş" değil "geç açılıyor" diye
  /// okunuyor. Altıncı adımdan sonra hepsi birlikte gelir.
  int get _staggerSteps => widget.index < Entrance.maxStaggerSteps
      ? widget.index
      : Entrance.maxStaggerSteps;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutQuart);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Zamanlayıcı, hareket tercihi BİLİNDİKTEN sonra kurulur. initState'te
    // kurulursa azaltılmış modda da her öğe için boşuna bir timer açılıyordu
    // (uzun listede yüzlerce); ayrıca MediaQuery initState'te güvenilir
    // okunmaz.
    if (_started || prefersReducedMotion(context)) return;
    _started = true;
    Future<void>.delayed(widget.delayStep * _staggerSteps, () {
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
    // Hareket azaltılmışsa giriş animasyonu HİÇ oynamaz: içerik doğrudan
    // yerinde belirir. Kademeli giriş dekoratiftir — bilgi taşımaz, o yüzden
    // kesilmesi hiçbir şeyi eksiltmez.
    if (prefersReducedMotion(context)) return widget.child;

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
