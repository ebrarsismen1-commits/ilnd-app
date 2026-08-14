import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Nefes alma animasyonu — dairesel pulse, "al / tut / ver" rehberi ile.
///
/// Faz etiketleri l10n'dan enjekte edilir (varsayılanlar TR) — İngilizce
/// kullanıcı "in / hold / out" görür.
class BreathAnimation extends StatefulWidget {
  const BreathAnimation({
    super.key,
    required this.p,
    this.inhaleLabel = 'al',
    this.holdLabel = 'tut',
    this.exhaleLabel = 'ver',
  });

  final AppPalette p;
  final String inhaleLabel;
  final String holdLabel;
  final String exhaleLabel;

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

  late String _label = widget.inhaleLabel;

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
      next = widget.inhaleLabel;
    } else if (t < _inhale + _hold) {
      next = widget.holdLabel;
    } else {
      next = widget.exhaleLabel;
    }
    if (next != _label) setState(() => _label = next);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_updateLabel);
    _ctrl.dispose();
    super.dispose();
  }

  /// 14 sn'lik döngü içindeki faz ilerlemesi: alırken 0→1 dolar, tutarken
  /// dolu kalır, verirken 1→0 boşalır. Etraftaki yay bunu çizer — göz,
  /// nefesle birlikte hareket eder.
  double get _phaseProgress {
    final t = _ctrl.value * _total;
    if (t < _inhale) return t / _inhale;
    if (t < _inhale + _hold) return 1.0;
    return 1.0 - (t - _inhale - _hold) / _exhale;
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
            // Faz yayı: nefesin kendisini çizen halka (al=dolar, ver=boşalır).
            CustomPaint(
              size: const Size(252, 252),
              painter: BreathPhaseArcPainter(
                progress: _phaseProgress,
                track: p.accent.withValues(alpha: 0.15),
                fill: p.accent,
              ),
            ),
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

/// Nefes fazını çizen yay: al fazında saat 12'den dolar, tut boyunca dolu
/// bekler, ver fazında geri boşalır. Nefesle senkron tek görsel rehber.
class BreathPhaseArcPainter extends CustomPainter {
  const BreathPhaseArcPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = fill,
    );
  }

  @override
  bool shouldRepaint(BreathPhaseArcPainter old) =>
      old.progress != progress || old.fill != fill || old.track != track;
}

/// Tam ekran nefes egzersizi — süreli seans (1/2/3 dk), seans ilerlemesini
/// gösteren halka ve yumuşak bir bitiş anı. Sonsuz döngü değil: her seansın
/// bir sonu ve "tamamladım" hissi vardır.
class BreathScreen extends StatefulWidget {
  const BreathScreen({super.key, required this.p});
  final AppPalette p;

  static const sessionOptions = [1, 2, 3]; // dakika

  @override
  State<BreathScreen> createState() => _BreathScreenState();
}

class _BreathScreenState extends State<BreathScreen> {
  int _minutes = 2;
  late int _remaining = _minutes * 60;
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _done = true;
        });
        return;
      }
      setState(() => _remaining--);
    });
  }

  void _selectMinutes(int m) {
    setState(() {
      _minutes = m;
      _remaining = m * 60;
      _done = false;
    });
    _startTimer();
  }

  void _restart() => _selectMinutes(_minutes);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = widget.p;
    final total = _minutes * 60;
    // Seans, 14 sn'lik nefes döngüleri olarak gösterilir: "nefes 3 / 8".
    final totalCycles = (total / 14).floor().clamp(1, 99);
    final currentCycle = (((total - _remaining) ~/ 14) + 1).clamp(
      1,
      totalCycles,
    );
    final mm = (_remaining ~/ 60).toString();
    final ss = (_remaining % 60).toString().padLeft(2, '0');

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
          l10n.breathScreenTitle,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w300,
            color: p.text,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOut,
        child: _done
            ? _BreathDoneView(
                key: const ValueKey('done'),
                p: p,
                onAgain: _restart,
              )
            : Column(
                key: const ValueKey('session'),
                children: [
                  const SizedBox(height: 12),
                  // Seans süresi çipleri — seçim geri sayımı yeniden başlatır.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final m in BreathScreen.sessionOptions) ...[
                        _MinuteChip(
                          p: p,
                          label: l10n.breathMinutesChip(m),
                          selected: m == _minutes,
                          onTap: () => _selectMinutes(m),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const Spacer(),
                  // Nefes halkası — faz yayı artık halkanın kendi parçası:
                  // alırken dolar, tutarken bekler, verirken boşalır.
                  BreathAnimation(
                    p: p,
                    inhaleLabel: l10n.breathPhaseInhale,
                    holdLabel: l10n.breathPhaseHold,
                    exhaleLabel: l10n.breathPhaseExhale,
                  ),
                  const SizedBox(height: 36),
                  // Döngü ilerlemesi: her tamamlanan nefes bir nokta doldurur.
                  Text(
                    l10n.breathCycleProgress(currentCycle, totalCycles),
                    style: TextStyle(
                      fontSize: 13,
                      color: p.text,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < totalCycles; i++) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          width: i < currentCycle ? 9 : 7,
                          height: i < currentCycle ? 9 : 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < currentCycle
                                ? p.accent
                                : p.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        if (i < totalCycles - 1) const SizedBox(width: 7),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$mm:$ss  ·  4 · 4 · 6',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: p.textMuted.withValues(alpha: 0.7),
                      letterSpacing: 2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
      ),
    );
  }
}

class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.p,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppPalette p;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? p.accent : p.border,
            width: selected ? 1.4 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? p.onAccent : p.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Seans bitti: yumuşak tamamlama anı — kapat ya da bir tur daha.
class _BreathDoneView extends StatelessWidget {
  const _BreathDoneView({super.key, required this.p, required this.onAgain});

  final AppPalette p;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.accentSoft,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.spa_rounded, size: 42, color: p.accent),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.breathDoneTitle,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w400,
              color: p.text,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.breathCloseButton,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.onAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onAgain,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l10n.breathAgainButton,
                style: TextStyle(fontSize: 13, color: p.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
